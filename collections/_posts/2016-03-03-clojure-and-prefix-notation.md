---
layout: post
title: Clojure and Polish Notation
category:
- Technology
- Software Engineering
- Computer Science
comments: true
featured: true
summary: Clojure syntax uses prefix notation and lots of parentheses. That sounds scary if you grew up on infix, but it doesn’t have to be.
tags:
- technology
- software
- computer-science
---
Clojure is a functional programming language for the JVM created by Rich Hickey. It is a dialect of Lisp, which is famous for its use of parentheses and a prefix-style syntax often associated with Polish notation.

In Lisp and Clojure, code is written as fully parenthesized S-expressions, with the operator first and the arguments after it. For example:

{% highlight clojure %}
(+ 3 4 (+ 3 3 5))
{% endhighlight %}

To many people this looks terrifying: so many parentheses, and the operator in "the wrong place".

I get why. We are taught infix notation all through school and then see it in most mainstream languages. Switching to prefix feels unnatural at first. The good news is that once you see the structure behind it, it actually becomes easier to reason about -- it just takes a little patience.

### Thinking in trees

Clojure’s syntax makes a lot of sense if you picture expressions as trees.

Take the simple expression `(* A B)`, which is equivalent to infix `A * B`. As a tree, it looks like this:

        *
      /   \
     A     B

The S-expression `(* A B)` is just a linear way to write that tree: put the operator at the front, then the operands, and wrap the whole thing in parentheses.

So you can think of Clojure’s "prefix notation" as:

- A tree of operations and values
- Written in one line as a parenthesized list: operator first, then its children

Once that clicks, nested expressions start to feel very natural, because the code mirrors the tree structure directly.

### "But I already use prefix, don’t I?"

Prefix notation sounds exotic, but you already use something very close to it in other languages.

In Python, a simple print looks like this:

{% highlight python %}
print("Hello World!")
{% endhighlight %}

The function name comes first, followed by the argument in parentheses.

In Clojure, the equivalent is:

{% highlight clojure %}
(print "Hello World!")
{% endhighlight %}

Same idea: the "operation" is at the front, followed by its arguments. The main differences are:

- Clojure uses a single pair of parentheses around the entire call
- Arguments are separated by spaces instead of commas

So while math operators like `+`, `-`, `*`, and `/` look unusual in prefix form, most other function calls feel very familiar once you notice this pattern.

### Readability and taste

I have never built a full-scale production system in Clojure or Lisp, but I still find Clojure code easier to read than a lot of Java code.

It is easy to make Java code look horrible. It is surprisingly hard to make Clojure code look horrible in the same way, because:

- The syntax is extremely regular
- The structure of the code mirrors the structure of the data and the operations

That doesn’t mean nobody can write unreadable Clojure, but you have to work a bit harder to fight the language.

### Further reading and watching

If you’re curious about the learning curve and the "Lisp way" of thinking, I highly recommend:

- [The Nature of Lisp](http://www.defmacro.org/ramblings/lisp.html)
- [2 Myths and 2 Facts About Clojure That Change Everything](http://blog.cognitect.com/blog/2015/9/21/2-myths-and-2-facts-about-clojure-that-change-everything)

Some talks and articles that were shared in the original Java Ranch thread:

- [(Neal's) Master Plan for Clojure Enterprise Mindshare Domination – Neal Ford](https://www.youtube.com/watch?v=2WLgzCkhN2g&feature=youtu.be&t=1619)
- [Simple Made Easy – Rich Hickey](http://www.infoq.com/presentations/Simple-Made-Easy)
- [Sneaking Clojure Past the Boss](http://www.coderanch.com/t/586641/clojure/Sneaking-Clojure-Boss)
- [Selling Clojure to Business](https://blog.juxt.pro/posts/selling-clojure.html)
- [PolyConf 15: Contracts as Types – Jessica Kerr](https://www.youtube.com/watch?v=zLyd_Ey1GPM)

If prefix notation and all those parentheses still feel odd, that’s fine. Our brains are heavily trained on infix. Spend a bit of time thinking in trees instead of lines of code, and Clojure’s syntax starts to feel less like an alien language and more like a very direct way of writing down structure.


Edit: (28th Nov 2025) Updated with latest understanding of some terminology. 
