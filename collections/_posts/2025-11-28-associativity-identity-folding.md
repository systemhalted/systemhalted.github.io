---
layout: post
title: Associativity, Identity, and Folding - Why Your reduce Keeps Biting You
category:
- Computer Science
- Software Engineering
- Technology
tags:
- java
- streams
- reduce
- functional programming
- algebra
comments: true
featured: true
description: A practical look at associativity, identity, and folding in Java Streams, and why some reduce calls behave nicely while others explode in surprising ways.
---
If you write Java today, you probably use `Stream.reduce` or something like it.

Sometimes it feels magical.

{% highlight java %}
int sum = nums.stream().reduce(0, Integer::sum);
{% endhighlight %}

Other times it feels cursed.

{% highlight java %}
int weird = nums.parallelStream().reduce(0, (a, b) -> a - b);
{% endhighlight %}

Same method, very different behavior.

Underneath these differences are three simple ideas:

1. Associativity  
2. Identity  
3. Folding (reducing a collection into one value)

You do not need category theory to use them. You just need to recognize when your operation behaves like `+` (associative) and when it behaves like `-` (non-associative).

This post walks through concrete Java examples you are likely to hit in normal work and uses them to build intuition for those three words.

It also gives you an understanding of when using parallelStreams is probably safe. 

---

## Folding: what `reduce` really does

A fold or reduce is just this:

Start with some value.  
Combine it with each element in a collection.  
End up with a single result.

For example, summing numbers by hand:

1. Start with `0`  
2. Add the first number  
3. Add the second number  
4. Keep going until you have one, final, number left

In Java Streams:

{% highlight java %}
int sum = nums.stream()
        .reduce(0, (acc, x) -> acc + x);
{% endhighlight %}

`reduce` needs two things from you.

1. An initial value, sometimes called the identity.  
2. A function that combines the accumulator and the next element.

Everything else in this post is about choosing those two well.

---

## Example 1: Integer sum, the happy path

Summing integers is the canonical example of reduce working perfectly, even in parallel.

{% highlight java %}
import java.util.List;

List<Integer> nums = List.of(1, 2, 3, 4, 5);

// Sequential
int sum1 = nums.stream()
        .reduce(0, Integer::sum);

// Parallel
int sum2 = nums.parallelStream()
        .reduce(0, Integer::sum);

System.out.println(sum1); // 15
System.out.println(sum2); // 15
{% endhighlight %}

Why does this behave?

The short version:

1. Addition is associative.  
2. Zero is the identity for addition.

Let us unpack that.

Associativity means you can change parentheses without changing the result:

{% highlight java %}
int a = (1 + 2) + 3;
int b = 1 + (2 + 3);
// a == b
{% endhighlight %}

Zero is the identity for `+` because it does nothing:

{% highlight java %}
0 + x == x;
x + 0 == x;
{% endhighlight %}

When both of these are true, the stream framework is free to:

1. Split the list into chunks.  
2. Sum each chunk separately.  
3. Add the partial sums in any grouping it likes.

Sequential or parallel, left grouped or right grouped, the result is always the same.

---

## Example 2: Subtraction with reduce, same shape, weird result

Change one thing. Use subtraction instead of addition.

{% highlight java %}
List<Integer> nums = List.of(1, 2, 3, 4, 5);

// Sequential
int result1 = nums.stream()
        .reduce(0, (a, b) -> a - b);

// Parallel
int result2 = nums.parallelStream()
        .reduce(0, (a, b) -> a - b);

System.out.println(result1);
System.out.println(result2);
{% endhighlight %}

On most machines you will see different numbers printed.

Subtraction is not associative:

{% highlight java %}
int a = (1 - 2) - 3;  // -4
int b = 1 - (2 - 3);  //  2
// a != b
{% endhighlight %}

Once the operation is not associative, the way the stream groups operations changes the result.

Sequential `reduce` tends to behave as if it were:

{% highlight java %}
((((0 - 1) - 2) - 3) - 4) - 5;
{% endhighlight %}

Parallel `reduce` might do something more like:

{% highlight java %}
(0 - (1 - 2)) - (3 - (4 - 5));
{% endhighlight %}

Same numbers, same lambda, same `reduce` method. Different grouping, different answer.

The day to day lesson:

When you pass a lambda as the combiner to `reduce`, ask yourself whether it behaves more like `+` or more like `-`. If it is like `-`, parallel reduction will be surprising.

---

## Example 3: Wrong identity value leads to skewed output

Even if your operation is associative, choosing the wrong initial value quietly skews your result.

{% highlight java %}
List<Integer> nums = List.of(1, 2, 3);

// Wrong identity: 1 instead of 0
int sum = nums.stream()
        .reduce(1, Integer::sum);

System.out.println(sum);  // 7, but the real sum is 6
{% endhighlight %}

Sequentially this works out as:

{% highlight java %}
(((1 + 1) + 2) + 3) == 7;
{% endhighlight %}

In parallel, the identity can be applied to every chunk, so the effect is even stranger.

The identity should be a ==do nothing== value for the operation:

```
combine(identity, x) == x  
combine(x, identity) == x
```

For addition, the identity is `0`. For multiplication, it is `1`. For string concatenation, it is `""`.

The day to day rule:

If you call `reduce(identity, combiner)`, check those two equations in your head for the operation you are using.

---

## Example 4: String concatenation, grouping versus ordering

String concatenation is another operation you use constantly.

{% highlight java %}
List<String> words = List.of("a", "b", "c");

String s1 = words.stream()
        .reduce("", (a, b) -> a + b);

String s2 = words.parallelStream()
        .reduce("", (a, b) -> a + b);

System.out.println(s1);  // usually "abc"
System.out.println(s2);  // also usually "abc"
{% endhighlight %}

Concatenation is associative:

{% highlight java %}
("a" + "b") + "c" == "a" + ("b" + "c");
{% endhighlight %}

and the empty string is the identity:

{% highlight java %}
"" + s == s;
s + "" == s;
{% endhighlight %}

So grouping does not matter.

Order still matters though:

{% highlight java %}
"a" + "b" != "b" + "a";
{% endhighlight %}

Concatenation is associative but not commutative.

Streams will respect encounter order unless you explicitly undo that. So in practice the result is stable, but the moment you introduce reordering operations you lose that guarantee.

The message here:

1. Associativity protects you from grouping changes.  
2. Commutativity protects you from ordering changes.  
3. Most real world operations are not commutative, so do not assume order is irrelevant unless you are sure.

---

## Example 5: Floating point sums, almost associative

Now a more subtle one: floating point numbers.

{% highlight java %}
List<Double> values = List.of(
        1e16, 1.0, 1.0, 1.0, 1.0
);

double s1 = values.stream()
        .reduce(0.0, Double::sum);

double s2 = values.parallelStream()
        .reduce(0.0, Double::sum);

System.out.println(s1);
System.out.println(s2);
{% endhighlight %}

In real math, addition is associative. In IEEE double precision, it is only approximately so.

When you add a very large number and a very small number, the small number can get rounded away. Different groupings of additions can lose or keep different tiny pieces of information.

Practically you see things like:

1. Slightly different sums when you use parallel streams.  
2. Results like `999.9999999997` instead of `1000.0`.

For many applications this does not matter. For financial calculations it absolutely does, which is one reason developers reach for `BigDecimal` or integer cents rather than `double`.

The take away:

Floating point addition mostly behaves like a good associative operation, but not perfectly. Do not expect bit identical results when you regroup or parallelise floating point reductions.

---

## Example 6: Merging counts in maps, a realistic associative operation

Imagine you have words and you want to count how many times each appears.

> A Note on Engineering vs. Math:
> While our Counts merge logic is mathematically associative (satisfying the requirements for reduce), using reduce for mutable objects like Maps is inefficient. It creates a copy of the map at every step.
> In Java, when you need to combine mutable containers (like Lists or Maps) in parallel, you should use the Mutable Reduction pattern via Stream.collect.

First, a small helper type:

{% highlight java %}
import java.util.Map;
import java.util.HashMap;

record Counts(Map<String, Integer> counts) {

    static Counts empty() {
        return new Counts(new HashMap<>());
    }

    Counts addWord(String word) {
        Map<String, Integer> copy = new HashMap<>(counts);
        copy.merge(word, 1, Integer::sum);
        return new Counts(copy);
    }

    Counts combine(Counts other) {
        Map<String, Integer> copy = new HashMap<>(counts);
        other.counts.forEach((w, c) ->
                copy.merge(w, c, Integer::sum));
        return new Counts(copy);
    }
}
{% endhighlight %}

Now we can use `reduce` with this.

{% highlight java %}
import java.util.List;

List<String> words = List.of("a", "b", "a", "c", "b", "a");

Counts result = words.parallelStream()
        .map(w -> Counts.empty().addWord(w))  // each word → its own count map
        .reduce(Counts.empty(), Counts::combine);

System.out.println(result.counts());
// {a=3, b=2, c=1}
{% endhighlight %}

Why this works well:

1. `combine` is associative.  
   Combining `(A combine B) combine C` gives the same counts as `A combine (B combine C)`.  

2. `Counts.empty()` is an identity.  
   Combining `empty` with any `Counts` yields that `Counts` back.

That is exactly what a framework like `reduce` wants: an associative operation with an identity element.

This is the same pattern you see in log aggregation, metrics systems, and analytics jobs. It is not an abstract trick, it is a workhorse.

---

## A mental checklist for `reduce`

Whenever you write something like:

{% highlight java %}
X result = stream.reduce(identity, (a, b) -> combine(a, b));
{% endhighlight %}

you can run a short mental checklist.

1. If I ignore floating point quirks, is `combine` associative?  

   combine(combine(a, b), c) == combine(a, combine(b, c))

2. Did I choose a true identity value?  
   Does `combine(identity, x)` give `x` and does `combine(x, identity)` give `x`?

3. Do I care about order?  
   If I do, am I doing anything that changes encounter order?

If the answer to 1 and 2 is yes, `reduce` is usually safe, even in parallel.  
If 1 or 2 fails, you either accept the weirdness, or you avoid `parallelStream` and regrouping.

---

Every `reduce` you write is a small promise.

You are telling the runtime:

1. Here is how to combine two partial results.  
2. Here is the neutral element that represents "no information yet".

If that promise matches reality, you get predictable, parallel friendly code.  
If it does not, you get ghosts: bugs that only appear under load, only with parallel streams, only with certain sizes of input.

Thinking in terms of associativity and identity is not about being fancy. It is just a way to make that promise explicit in your own head, instead of leaving it as "whatever this lambda does".

Once you start looking at your own code through that lens, you will find that a surprising amount of what you do every day is already algebra. You were just calling it "business logic".