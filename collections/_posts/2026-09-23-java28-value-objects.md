---
layout: post
title: "Java 28 Preview: Value Objects Bring Identity-Free Data to Java"
categories: [Software Engineering, Computer Science]
tags: [language design, jep, java, value objects, immutability, objects, oop, java runtime, AI-assisted]
toc: true
comments: true
description: How Java 28’s value objects bring identity-free data to Java, changing equality semantics and opening new JVM optimizations.
---

Java has always treated every object as a distinct thing with its own identity. That is the right model for mutable entities, but it has always been awkward for immutable data. A `LocalDate` for `1996-01-23` and another `LocalDate` for `1996-01-23` behave like the same value, yet the language has historically treated them as two different objects. The  JDK 28’s preview of value objects[^1] changes that. JEP 401[^2] introduces `value` classes: classes whose instances are immutable, interchangeable, and eligible for much more efficient runtime layouts.

## Why Java needed this

There are two issues with the current Java object model. The first is semantic. Developers learn that `==` tests object identity, while classes such as `LocalDate` define `equals()` in terms of their logical value. That distinction is useful when identity matters, but less natural for values. If two `LocalDate` instances represent the same date, we usually think of them as the same value.

The second problem is the runtime cost. Even when identity has no semantic value, the JVM must preserve it. Collections of small immutable objects can therefore require substantially more allocation and indirection than equivalent primitive data..

## What Java 28 adds

Java 28 introduces **value classes**, declared with the `value` modifier. Instances of those classes are **value objects**, defined by the values of its fields, not by a unique identity. Classes without the modifier remain ordinary identity classes.

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

The `==` still works exactly as it always has for identity objects. `String`, for example, remains an identity class.

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

But value classes are not limited to transparent record-style data. They can hide their representation details behind methods, preserving the abstraction of ordinary classes while allowing the JVM to treat their immutable data more like a raw value. They are therefore not simply "Java structs". 

## `==` is changing, but `equals()` still matters

`==` and `equals()` may often agree for value classes, but they differ in what they answer. A value class may have an internal representation that differs even when the logical value is the same. The proposal uses examples like substring wrappers and NaN payloads to show that two value objects can be logically equal without being indistinguishable field-by-field. `equals()` expresses semantic equality, while `==` asks whether two value objects are indistinguishable under the language rules.

## Why this matters for performance

Once a program can no longer observe identity for a value object, the JVM gains freedom in how it stores and moves that data. The proposal highlights two key optimizations:

- **Reference flattening**: a field or array element can directly encode the data of a value object instead of storing a pointer to a heap object.
- **Reference scalarization**: a local variable or method parameter can be broken into individual field values rather than carried around as a heap reference.

In practical terms, an array of `LocalDate` values may no longer require pointers to separately allocated objects. The JVM may instead store their data inline, reducing memory use and improving locality. More broadly, value objects give the JVM opportunities for primitive-like efficiency without sacrificing encapsulation or type safety.

## There are real behavioral changes to understand

Value objects are not a drop-in replacement for every immutable class. A few of the important caveats:

- You cannot synchronize on a value object. Identity-sensitive operations such as locking, `wait()`, and `notify()` do not make sense without identity.
- Migrating an existing class to a value class can break code that relied on object identity, public constructors, or `==` for uniqueness checks.
- Serialization of non-record value classes needs special handling through `writeReplace` and `readResolve`.
- Deep reflection cannot be used to mutate value-object fields.
- Identity-sensitive APIs such as weak references and `WeakHashMap` are not compatible with value objects.

There is also a subtle security and performance angle: because `==` now works recursively over fields for value objects, comparisons can expose more about object state than identity used to, and deep comparisons may be more expensive than developers expect.

The dividing line is identity. If uniqueness, synchronization, or identity-based behavior is part of the abstraction, it should remain an identity class.


## How to try it in JDK 28

Value objects are currently a preview feature in JDK 28 early-access builds, so they must be explicitly enabled.

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

Some platform classes become value classes only when preview features are enabled. Code compiled against those preview definitions must therefore also run with `--enable-preview`.

## Why this preview matters

VValue objects change a foundational assumption in Java: objects no longer necessarily imply identity. That lets developers model dates, coordinates, money, measurements, and similar values as classes while giving the JVM more freedom to optimize their representation.  



-----

## References and Notes

[^1]: Java 28 binaries are available as early release. So, you won't find them on `mise` or `sdkman`.
[^2]:  JEP 401: Value Objects (Preview), [jep401](https://openjdk.org/jeps/401). 
