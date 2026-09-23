---
layout: post
title: "Java 28 Preview: Value Objects Bring Identity-Free Data to Java"
categories: [Software Engineering, Computer Science]
tags: [language design, jep, java, value objects, immutability, objects, oop, java runtime]
toc: true
comments: true
description: This post explores the Java 28 value objects JEP
---

Java has always treated every object as a distinct thing with its own identity. That is the right model for mutable entities, but it has always been awkward for immutable data. A `LocalDate` for `1996-01-23` and another `LocalDate` for `1996-01-23` behave like the same value, yet the language has historically treated them as two different objects. JDK 28’s preview of value objects changes that. JEP 401[^1] introduces `value` classes: classes whose instances are immutable, interchangeable, and eligible for much more efficient runtime layouts.

This is a bigger shift than it first appears. Value objects are not just "small immutable classes with nicer syntax." They change what `==` means for a specific kind of object, they let the JVM stop treating every immutable value as a separately allocated heap object, and they bring Java closer to the way developers already think about dates, numbers, money, optionals, and other simple data.

## Why Java needed this

Java’s object model has carried a long-standing mismatch: every object has identity, even when identity adds no business value. There are two issues with this approach. First, it is confusing. Developers learn early that `equals()` compares content while `==` compares identity. That makes sense for mutable objects, but it feels unnatural for immutable values. If two `LocalDate` instances represent the same date, most people instinctively think of them as the same thing.

Second, it is expensive. If every immutable value must still be a separately identifiable object, the JVM has to preserve that identity. That typically means heap allocation, object headers, pointer chasing, and more work for the garbage collector. Arrays of `LocalDate` references, for example, are much heavier than arrays of primitive values, even though a date is really just a small bundle of data.

Value objects address both problems by letting class authors opt out of identity when identity is not needed.

## What Java 28 adds

Java 28 introduces **value classes**, declared with the `value` modifier. Instances of those classes are **value objects**. Classes without the modifier remain ordinary identity classes.

The core idea of value classes is that *a value object is defined by the values of its fields, not by a unique identity in memory*.

That affects the language in a few important ways:

- Value objects are still objects. They have fields and methods, are handled through references, and can still be `null`.
- They are immutable by construction. Instance fields are implicitly final.
- The JVM is no longer required to represent a value object as a distinct heap object with a pointer-based identity.
- For value objects, `==` compares **indistinguishability by field values**, not pointer identity.

Under preview, some existing platform classes become value classes, including boxed primitives like `Integer`, `Optional` types, and many `java.time` types such as `LocalDate`, `LocalTime`, and `Duration`.

So code like this changes meaning:

```java
Integer x = 1996, y = 1996;
System.out.println(x == y); // true with preview-enabled value objects
```

Likewise:

```java
var d1 = LocalDate.of(1996, 1, 23);
var d2 = d1.plusYears(30).minusYears(30);

System.out.println(d1 == d2); // true with preview-enabled value objects
```

That is a meaningful shift, but it is also carefully scoped. `==` still works exactly as it always has for identity objects. `String`, for example, remains an identity class.

## What a value class looks like

The simplest examples are records:

```java
value record Point(int x, int y) {}
```

Two separately created `Point` instances with the same coordinates are indistinguishable:

```java
Point p1 = new Point(17, 3);
Point p2 = new Point(17, 3);

System.out.println(p1 == p2);                // true
System.out.println(Objects.hasIdentity(p1)); // false
```

But value classes are not limited to transparent record-style data. You can still hide representation details behind methods, which is important for domain types like money, ranges, measurements, or compressed encodings.

That means value objects are not "Java structs." They keep the abstraction benefits of classes while letting the runtime treat immutable data more like raw values when it can.

## `==` is changing, but `equals()` still matters

One easy mistake would be to read this feature as "Java is replacing `equals()` with `==`." It is not.

For many value classes, `==` and `equals()` will often produce the same answer. But not always.

A value class may have an internal representation that differs even when the logical value is the same. The proposal uses examples like substring wrappers and NaN payloads to show that two value objects can be logically equal without being indistinguishable field-by-field. In other words, `equals()` still represents your semantic notion of value equality, while `==` answers a narrower question: are these two value objects indistinguishable under the language rules?

That means the usual advice still stands: use `equals()` for most logical comparisons in application code. Value objects make `==` less surprising in some cases, but they do not eliminate the need for good equality design.

## Why this matters for performance

The runtime story here is just as important as the language story.

Once a program can no longer observe identity for a value object, the JVM gains freedom in how it stores and moves that data. The proposal highlights two key optimizations:

- **Reference flattening**: a field or array element can directly encode the data of a value object instead of storing a pointer to a heap object.
- **Reference scalarization**: a local variable or method parameter can be broken into individual field values rather than carried around as a heap reference.

In practical terms, this means arrays of immutable values can become much denser and more cache-friendly. An array of `LocalDate` values may no longer need to be an array of pointers to separately allocated objects. The JVM may be able to store the date fields inline, reducing memory footprint and improving locality.

This is why value objects matter beyond syntax. They create room for the JVM to deliver primitive-like efficiency for many domain types without forcing developers to give up encapsulation and type safety.

## There are real behavioral changes to understand

Value objects are a powerful feature, but they are not a drop-in replacement for every immutable class.

A few of the important caveats:

- You cannot synchronize on a value object. Identity-sensitive operations such as locking, `wait()`, and `notify()` do not make sense without identity.
- Migrating an existing class to a value class can break code that relied on object identity, public constructors, or `==` for uniqueness checks.
- Serialization of non-record value classes needs special handling through `writeReplace` and `readResolve`.
- Deep reflection cannot be used to mutate value-object fields.
- Identity-sensitive APIs such as weak references and `WeakHashMap` are not compatible with value objects.

There is also a subtle security and performance angle: because `==` now works recursively over fields for value objects, comparisons can expose more about object state than identity used to, and deep comparisons may be more expensive than developers expect.

In short, value objects are a great fit for immutable, interchangeable data. They are a bad fit for anything whose behavior depends on uniqueness, locking, lifecycle hooks, or identity-based caches.

## Safer construction is part of the model

One of the more interesting parts of the proposal is not visible in everyday code: value objects come with stricter construction rules.

Because a value object has no identity, it must never be observed in a partially initialized state. To guarantee that, constructor code for value classes runs under safe construction constraints that prevent early leakage of `this`. That protects invariants and ensures recursive `==` comparisons cannot run into cycles created during construction.

## How to try it in JDK 28

Value objects are a **preview feature** in JDK 28, so they are disabled by default.

To try them:

```bash
javac --release 28 --enable-preview Main.java
java --enable-preview Main
```

Or, if you are using the source launcher:

```bash
java --enable-preview Main.java
```

And for JShell:

```bash
jshell --enable-preview
```

One subtle detail is especially important: some platform classes only become value classes when preview is enabled. If you compile without preview, classes such as `LocalDate` behave the way they did before. If you compile with preview enabled, you are compiling against the new value-object version and must also run with preview enabled.

## Why this preview matters

Value objects are one of the most consequential shifts to Java’s object model in a long time. They acknowledge something developers have known for years: not every object needs identity, and forcing identity on immutable data has both semantic and performance costs.

If this feature lands well, it opens the door to a more expressive and more efficient Java. Developers get to model dates, coordinates, money, measurements, wrappers, and other simple values as full-fledged classes without paying the traditional "every object is a unique heap thing" tax. The JVM gets more freedom to optimize. And Java code gets closer to the way people already reason about immutable data.

-----

## References and Notes

[^1]:  JEP 401: Value Objects (Preview), [jep401](https://openjdk.org/jeps/401)