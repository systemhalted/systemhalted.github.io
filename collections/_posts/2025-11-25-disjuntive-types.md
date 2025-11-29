---
layout: post
title: Either This Or That - Why I Wanted Disjunctive Types In Java
category: [Computer Science, Programming, Software Engineering, Technology]
tags: [disjunction, Scala, Java, Kotlin, Haskell, Algebraic Data Types]
comments: true
description: When your Java methods really mean "either this or that" but the type system only says "here’s something…maybe," you’re flying blind. This post walks through using Result types, sealed hierarchies, and a bit of logic-thinking to make those hidden alternatives explicit, so the compiler – not your Javadoc – tells the truth about your code.
featured: true
---

A few years ago at work, while hacking on a parser and analyser, I realised I needed something my language did not give me: disjunctive types.

Java did not have it.  
Kotlin did not have it.  
Scala did, in the form of `Either`.

I found `Either` while searching through Scala docs and it felt exactly right for the problem in front of me. Simple idea, huge leverage. That sent me down the path of thinking about what disjunctive types really are and why I want them in my everyday Java code.

---

## Where My Idea Of Disjunctive Types Comes From

My mental model of disjunctive types comes from logic.

First, think about ordinary disjunction, the familiar logical OR. A disjunction `A ∨ B` is true whenever at least one of its arguments is true and both are not simultaneously false.

You can write the truth table like this:

| A | B | A ∨ B |
|---|---|-------|
| 0 | 0 | 0     |
| 0 | 1 | 1     |
| 1 | 0 | 1     |
| 1 | 1 | 1     |

This version is often called inclusive disjunction, because the case where both `A` and `B` are true still counts as true.

There is another flavour: exclusive disjunction. Here the result is true only when the two arguments differ. In boolean logic this is the XOR gate, usually written as `A ⊕ B`.

| A | B | A ⊕ B |
|---|---|-------|
| 0 | 0 | 0     |
| 0 | 1 | 1     |
| 1 | 0 | 1     |
| 1 | 1 | 0     |

This second table matches how I think about disjunctive types in programming languages. In plain English it is the phrase "either this or that". A value of such a type holds one variant or the other, but not both at the same time.

---

## Conjunctive Types And Their Limits

Most of the time, existing data structures are enough.

If I want to group several fields together, I can define a record, a data class, or a POJO. These are conjunctive types: they say "you get this and that and that".

For example, if I want a result that always includes both a status and a payload, a simple class like this works fine:


{% highlight java %}
public final class ResultWithStatus {
    private final Status status;
    private final Payload payload;

    public ResultWithStatus(Status status, Payload payload) {
        this.status = status;
        this.payload = payload;
    }

    public Status status() {
        return status;
    }

    public Payload payload() {
        return payload;
    }
}
{% endhighlight %}

Here the idea really is "status and payload together", so a conjunction feels natural.

There are situations where this does not reflect the intent.

Sometimes a method should return one of two different shapes of data. A very common example is a method that either returns a successful result or an error description.

In that case a pure conjunction feels awkward. I can create a wrapper object that has both fields and then abuse `null` for whichever field is absent at the moment:

{% highlight java %}
public final class BadResult {
    private final Payload payload;  // null when there is an error
    private final Error error;      // null when there is a payload

    public BadResult(Payload payload, Error error) {
        this.payload = payload;
        this.error = error;
    }

    public Payload payload() {
        return payload;
    }

    public Error error() {
        return error;
    }
}
{% endhighlight %}

The type says "payload and error", but the runtime behaviour says "either payload or error". The compiler cannot help here. Nothing stops me from building a value that has both fields non null or both null.

What I really want is a type that expresses the "either this or that" constraint directly.

---

## Enter Disjunctive Types

This is where disjunctive types become interesting. A typical example in functional languages is something like:

{% highlight java %}
sealed trait Either[+A, +B]
final case class Left[A](value: A) extends Either[A, Nothing]
final case class Right[B](value: B) extends Either[Nothing, B]
{% endhighlight %}

A value of type `Either[A, B]` is always either a `Left[A]` or a `Right[B]`, never both at once. That mirrors the exclusive disjunction table from earlier.

In a language like Scala, returning

{% highlight scala %}
    def parse(input: String): Either[ParseError, Ast]
{% endhighlight %}

is completely natural. Callers are forced to handle both cases. Pattern matching makes the intent very clear:

{% highlight scala %}
    parse(source) match {
      case Left(error)  => log(error)
      case Right(ast)   => evaluate(ast)
    }
{% endhighlight %}

No nulls. No dummy wrapper objects. The type itself documents the contract of the method.

---

## What About `Optional` In Java?

As soon as you talk about "maybe this, maybe that" in Java, `Optional<T>` shows up in the conversation.

`Optional<T>` is useful, but it solves a weaker problem.

In type-theory style shorthand you can think of it as:

    Optional<T> ≈ Either<Unit, T>

which reads as "either there is nothing interesting here, or there is a `T`". The second branch of the disjunction is just absence. 

The set of all possible values for `Optional<T>` is

    `Optional⟨T⟩ = {None} ∪ {Some(t) | t ∈ T}` 

That makes `Optional<T>` perfect for things like map lookups:

{% highlight java %}
    Optional<Value> maybeValue = Optional.ofNullable(map.get(key));
{% endhighlight %}

Sometimes the key exists, sometimes it does not. The "other side" of the result is simply "no value".

Now look at the parser example again. If I write:

{% highlight java %}
    Optional<Ast> parse(String input);
{% endhighlight %}

then an empty `Optional` only tells me that parsing failed. It does not tell me why it failed. All the interesting information about the error has to live somewhere else: logs, exceptions, some side channel.

This is not what I want for the `parse` method. The contract of the method is not "Ast or nothing". The real contract is "either a `ParseError`, or an `Ast`".

That is a different shape altogether:

{% highlight java %}
    // Conceptual, not real Java
    Either<ParseError, Ast> parse(String input);
{% endhighlight %}

Here both branches are meaningful. The "left" side carries structured error data, not a vague absence. The caller has to consider both cases, and the type system helps enforce that.

So the distinction looks like this:

> Use `Optional<T>` when the alternative is "no value".  
> Use `Either<A, B>` when the alternative is "a different, meaningful value".

`Optional` is still valuable. It cleans up a lot of cases where we used to throw around naked nulls. It just does not replace a genuine disjunctive type where both branches have real content.

---

## How Do You Handle This In Java Today?

Once you see that you want "either this or that" in the type system, the next question is obvious: what can you actually do in Java right now?

### Exceptions: The Classic Java Way

The traditional Java approach is:

    Ast parse(String input) throws ParseException

On success you get an `Ast`. On failure you get a thrown `ParseException`.

This has some clear advantages. It is familiar to Java developers and the error can carry rich data, stack trace, nested causes. The downside is that the control flow is invisible in the type. The method signature looks like "returns `Ast`", but semantically it is "returns `Ast` or blows up".

You also get the whole checked versus unchecked exception debate, and callers can easily forget to handle failures or accidentally swallow exceptions.

Exceptions are one way of expressing a disjunction in Java, but they live outside the return type.

### Making The Disjunction Explicit: A `Result` Type

You can instead model the disjunction as data in the type system.

With modern Java, especially with sealed interfaces and records, this is not too painful. For Java 17 and above:

{% highlight java %}
public sealed interface Result<E, T>
        permits Result.Ok, Result.Err {

    record Ok<E, T>(T value) implements Result<E, T> { }

    record Err<E, T>(E error) implements Result<E, T> { }
}
{% endhighlight %}

Your parser then becomes:

    Result<ParseError, Ast> parse(String input);

Using it with pattern matching for `switch`:

{% highlight java %}
Result<ParseError, Ast> result = parse(source);

switch (result) {
    case Result.Ok<ParseError, Ast> ok -> {
        Ast ast = ok.value();
        evaluate(ast);
    }
    case Result.Err<ParseError, Ast> err -> {
        log(err.error());
    }
}
{% endhighlight %}

Now the disjunction is right there in the signature. No nulls. No surprise exceptions. The compiler forces you to think about both branches.

If you are not on a sealed-types Java yet, you can do a simpler interface plus nested classes:

{% highlight java %}
    public interface Result<E, T> {
      final class Ok<E, T> implements Result<E, T> {
          private final T value;
          public Ok(T value) {
              this.value = value;
          }
          public T value() {
              return value;
          }
      }
      
      final class Err<E, T> implements Result<E, T> {
          private final E error;
          public Err(E error) {
              this.error = error;
          }
          public E error() {
              return error;
          }
      }
   }
{% endhighlight %}

At this point you have your own mini-`Either` in Java.

Now you can use it like:

{% highlight java %}
   public Result<ParseError, Ast> parse(String input) {
        try {
            Ast ast = realParse(input); // imagine this may throw ParseException
            return new Result.Ok<>(ast);
        } catch (ParseException e) {
            return new Result.Err<>(new ParseError(e.getMessage()));
        }
   }
{% endhighlight %}

The calling code is then forced to check the result, for example, using ugly `instanceOf` :

{% highlight java %}
     Result<ParseError, Ast> result = parse(source);

    if (result instanceof Result.Ok<ParseError, Ast> ok) {
        Ast ast = ok.value();
        evaluate(ast);
    } else if (result instanceof Result.Err<ParseError, Ast> err) {
        ParseError error = err.error();
        log(error);
    
{% endhighlight %}

You can hate the verbosity of `instanceof`, but at least the type system is no longer lying about the fact that there are two meaningful branches.

---

## Disjunctive AST Nodes: An N-Way Either

In many real parsers, the "either this or that" situation is not just success versus error. Sometimes you are walking an abstract syntax tree (AST) and the node you are visiting could be one of several meaningful shapes.

For example, when traversing a PL/SQL file, you might encounter:

- a package
- a function  
- a stored procedure  
- or some other declaration further down the AST  

Conceptually, that return type is not "a function and a stored proc and a package". It is "either a package, or a function, or a stored proc, or something else".

In Java 17+, the cleanest way to express this is as a sealed hierarchy. The AST node type itself becomes a multi-way disjunctive type:

{% highlight java %}
    public sealed interface AstNode
            permits PackageNode, FunctionNode, StoredProcNode, OtherNode {
    }

    public final class PackageNode implements AstNode {
        // nested declarations, children, etc.
    }

    public final class FunctionNode implements AstNode {
        // function-specific fields
    }

    public final class StoredProcNode implements AstNode {
        // stored-procedure-specific fields
    }

    public final class OtherNode implements AstNode {
        // whatever other construct you have
    }
{% endhighlight %}

Now a traversal method can simply say:

{% highlight java %}
    AstNode visit(NodeContext ctx) {
        // logic that returns one of the concrete node types
    }
{% endhighlight %}    

And the consumer can handle all the possibilities with pattern matching:

{% highlight java %}
    AstNode node = visit(ctx);

    switch (node) {
        case PackageNode pkg      -> handlePackage(pkg);
        case FunctionNode fn      -> handleFunction(fn);
        case StoredProcNode sp    -> handleStoredProc(sp);
        case OtherNode other      -> handleOther(other);
    }

{% endhighlight %}    

That `AstNode` interface is an N-ary disjunctive type: "either a function, or a stored proc, or a package, or …". If you want to stack this with success/failure, you can even combine it:

    Result<ParseError, AstNode> visit(NodeContext ctx);

So you end up with:

- outer disjunction: `Result<Error, Value>` (success vs failure)  
- inner disjunction: `AstNode` being one of `{PackageNode, FunctionNode, StoredProcNode, OtherNode, …}`  

This is exactly the kind of situation where making the alternatives explicit in the type system keeps the code honest.

---

## Where `Optional` Still Fits

`Optional<T>` still has a clear niche: it fits when the alternative branch is "nothing to see here".

Typical cases:

    Optional<User> findById(String id);

    Optional<String> findHeader(String name);

These really are "value or no value" cases. There is no error object with rich semantics that you want to propagate. Once you have a meaningful error domain, you are back in `Result<E, T>` or some other disjunctive type.

So one way to think about the layering is:

- `Optional<T>` for "present or absent".  
- `Result<E, T>` (or `Either<A, B>`-style types) for "this meaningful thing or that meaningful thing".  
- Exceptions only for genuinely exceptional failures: bugs, I/O issues, broken invariants.  

---

## Mixing Exceptions And Results

You do not have to pick a single tool forever.

A pragmatic pattern looks like this:

- In lower-level logic and domain code, return `Result<E, T>` (or another explicit disjunctive type) to represent expected failures.  
- At the edges of the system, such as HTTP controllers or CLI handlers, translate `Result` into HTTP responses or user messages.  
- Throw exceptions only for truly unexpected situations, such as corrupted state or impossible code paths.  

That way you use disjunctive types for expected control flow, and keep exceptions for "this should not have happened".

---

## A Small Step You Can Take Right Now

If you want to live this idea in Java code today, you can:

1. Introduce a tiny `Result<E, T>` type as above in a shared utilities module.  
2. Start by using it in one or two flows, such as parsing or service calls.  
3. Add helper methods like `map`, `flatMap`, and `fold` later if you want a more functional style.  

With a helper class:

{% highlight java %}
    public final class Results {

        private Results() { }

        public static <E, T, U> Result<E, U> map(
                Result<E, T> result,
                java.util.function.Function<T, U> f
        ) {
            if (result instanceof Result.Ok<E, T> ok) {
                return new Result.Ok<>(f.apply(ok.value()));
            } else if (result instanceof Result.Err<E, T> err) {
                return new Result.Err<>(err.error());
            }
            throw new IllegalStateException("Unknown Result variant");
        }
    }
{% endhighlight %}

Once you have that, you can start composing operations without losing error context, all within the type system.

---

## Closing Thoughts

In most codebases we lean heavily on "and" types: records, POJOs, data classes that say "this and that and that". They are great when your domain really is a bundle of things that always travel together.

Disjunctive types live on the other side of that line. They say "either this or that" and force you to acknowledge both branches as first-class citizens. That is what `Either`, `Result<E, T>`, sealed AST hierarchies, and similar patterns bring to Java: a way to make alternatives part of the type story instead of an afterthought.

`Optional<T>` still earns its keep for "value or no value". Exceptions still matter for "this should never happen". But when the alternative is a meaningful value – a `ParseError`, a `ValidationError`, a different AST node type – it is worth promoting that alternative into the type system and letting the compiler nag you into handling it.

Once you start doing that, a lot of familiar patterns begin to look different. Classes full of nullable fields, APIs that quietly throw, methods whose real contract lives in Javadoc rather than in types – all of them start to feel like places where a missing "either this or that" is hiding in plain sight.
