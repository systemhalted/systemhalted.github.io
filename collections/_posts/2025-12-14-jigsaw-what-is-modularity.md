---
layout: post
title: Project Jigsaw (JPMS) - What is Modularity?
type: post
published: true
comments: true
categories:
  - Technology
  - Software Engineering
tags:
  - java
  - jdk9
  - project-jigsaw
  - jpms
  - modularity
  - module-info
description: "A practical definition of modularity in Java, why Jigsaw existed even though we already had packages and JARs, and what the module system actually enforces."
---

## A note from the future

I began this post in 2016, when Java 9 was still unreleased and Project Jigsaw felt like an approaching weather system. Java 9 eventually shipped, and the module system became real, imperfect, and unexpectedly enlightening.

This post keeps the original question intact: what is modularity and why did Java need the platform itself to care?

## Java already had "modules"... right?

For the past few years, Java has evolved quickly, mostly for the better. JDK 8 changed everyday Java with lambdas and streams, making a more functional style feel native instead of like cosplay.

Then came JDK 9 and Project Jigsaw, the Java Platform Module System (JPMS). The obvious objection was, and still is:

Java already has JARs. Enterprise Java has WARs and EARs. Source code has packages and access modifiers. So why add "modules" at all?

To answer that, we need to be annoyingly precise about what a module is.

## What is a module?

A module is not just "a bunch of related code." That definition is so generous it would make my `Downloads/` folder a module, and it absolutely should not be trusted with responsibility.

A better definition:

A module is a unit with an enforceable boundary.

In practice, a module needs at least these traits.

### 1. Encapsulation (a hidden interior)

Encapsulation is the right to say: "this part is implementation detail; do not touch."

Java supports encapsulation via access modifiers (`private`, package-private, `protected`, `public`) and via packages. In the POJO world, we keep fields private and expose behavior through methods so nobody can accidentally mutate internal state and then act surprised when physics happens.

But here is the catch:

Packages are excellent organizing units, but by themselves they are not deployment boundaries.

Once code is on the classpath, it tends to behave like a single sprawling neighborhood where everyone can wander into everyone else's backyard, sometimes through reflection, sometimes through "it was convenient," sometimes through sheer dependency gravity.

### 2. A public surface (an intentional API)

A module must have a public surface: a set of types meant to be used by outsiders.

This matters because modularity is not just hiding. It is also communicating on purpose.

When modules interact, they should do so through the exported API, not through accidental knowledge of internals. This is how systems remain refactorable without becoming brittle.

So far, this sounds like "write disciplined code," which is true, and still not the full story.

The painful question is: can the platform help enforce that discipline?

## Why packages and JARs were not enough?

Packages and JARs let us aspire to be modular. They do not consistently let us enforce it.

Here are the classic failure modes that show up as systems grow.

### 1. The classpath is a soup

The classpath is wonderfully simple and brutally permissive. Put things on it, and they exist.

Common outcomes:

* Accidental dependencies form silently.
* Internals become "public" by habit. "Just import it."
* Debugging becomes archaeology. "Who pulled in this version, and why does it only fail on Jenkins?"

### 2. JAR hell is real, and it has receipts

When multiple JARs provide overlapping classes, or when classloading order changes, you can get failures that only appear at runtime and only on certain machines.

Even when your build tool is trying to help, the model is still basically: assemble a pile of bytecode and hope it behaves.

### 3. Encapsulation at runtime was historically negotiable

Before JPMS, it was common for libraries to reach into non-public areas, either:

* Using reflection to access private members.
* Using internal JDK APIs because they existed and were "handy."

This worked until it did not. And the "did not" usually arrived as a production upgrade - not an upgrade by choice but force. 

### 4. Split packages and duplicate worlds

On the classpath you can end up with the same package name spread across multiple JARs. Tools can limp along, humans can suffer quietly, and then one day something breaks in a way that makes you question reality.

A modular system has to be stricter about identity, or it cannot reason about the graph.

## What Jigsaw actually adds

Project Jigsaw turns modularity into something the compiler and runtime can understand.

A Java module has:

* A name (a stronger identity than "whatever the filename is").
* Declared dependencies (what it requires).
* Declared exports (what it makes available to other modules).
* Strong encapsulation by default (if you do not export it, it is not part of your public world).

This is expressed with a module descriptor: `module-info.java`.

A minimal example:

{% highlight java %}
module com.example.billing {
    requires java.sql;
    exports com.example.billing.api;
}
{% endhighlight %}

The point is not ceremony. The point is boundaries that can be checked.

## Packages vs modules, a clean mental model

Think of it like this:

* A package groups related types and helps structure code.
* A module groups packages and declares which packages are visible to the outside world.

Packages help you organize. Modules help you enforce.

## "Enforce" how, exactly?

JPMS enforces things in two major places: compilation and runtime.

### 1. Reliable configuration (dependency truth)

With modules, dependencies are not an emergent property of "whatever happens to be on the classpath today."

Instead, the runtime resolves a module graph:

* Each module declares what it requires.
* The system checks that required modules exist.
* The system checks for conflicts that would make the graph incoherent.

This catches certain categories of surprise runtime failure earlier, because the platform can actually see your dependency structure.

### 2. Strong encapsulation (real boundaries)

With modules, code in a non-exported package is not accessible to other modules at compile time, and at runtime access is strongly controlled.

This is the key philosophical shift:

> You are not just suggesting which parts are internal. You are declaring it, and the platform can enforce it.

## A quick tour of module descriptor concepts

The `module-info.java` file is small, but it has teeth. Here are the ideas you will see in real projects.

### `requires`

A module can state that it depends on another module.

{% highlight java %}
module com.example.app {
    requires com.example.billing;
}
{% endhighlight %}

### `exports`

A module can export a package to make it part of its public API.

{% highlight java %}
module com.example.billing {
    exports com.example.billing.api;
}
{% endhighlight %}

Everything else stays internal by default.

There is also qualified export, where you export only to specific friend modules:

{% highlight java %}
module com.example.billing {
    exports com.example.billing.internal to com.example.app;
}
{% endhighlight %}

That is useful for tightly coupled modules, though it should be used sparingly because it creates special relationships that age poorly.

### `opens`

Exporting is about normal access. Opening is about reflection.

Frameworks use reflection for dependency injection, serialization, proxies, and other wizardry. JPMS makes you be explicit about that:

{% highlight java %}
module com.example.model {
    opens com.example.model.entities;
}
{% endhighlight %}

You can also open to specific modules only:

{% highlight java %}
module com.example.model {
    opens com.example.model.entities to com.fasterxml.jackson.databind;
}
{% endhighlight %}

## Services: `uses` and `provides`

The service mechanism is the module-friendly way to do plugin architecture.

Consumer:

{% highlight java %}
module com.example.app {
    uses com.example.spi.PaymentProvider;
}
{% endhighlight %}

Provider:

{% highlight java %}
module com.example.stripe {
    provides com.example.spi.PaymentProvider
        with com.example.stripe.StripePaymentProvider;
}
{% endhighlight %}

## But what about my existing non-modular JARs?

JPMS did not pretend the world would instantly become modular. It introduced a migration story, and it is worth understanding because it explains a lot of real-world behavior.

### The unnamed module

If you put JARs on the classpath instead of the module path, they effectively live in the unnamed module. This unnamed module can read everything, and everything can read it, which is intentionally permissive to keep legacy code running.

It is the compatibility bridge. It is also where modular purity goes to take a nap.

### Automatic modules

If you put a regular JAR on the module path, the system can treat it as an automatic module with a derived name and permissive readability rules.

This is a practical stepping stone, not a perfect end state.

A common migration path looks like:

* Run as classpath, accept the unnamed module.
* Move some things to module path, tolerate automatic modules.
* Modularize the important libraries and applications over time.

Not glamorous, but it works, and it respects the fact that software is mostly sedimentary rock.

## The JDK itself became modular

One of the most concrete outcomes of Jigsaw is that the JDK stopped being a monolith. It became a set of modules.

This matters because:

* The platform itself has clearer internal boundaries.
* The JDK can strongly encapsulate internal APIs, reducing accidental dependencies on JDK internals.
* Tools can assemble smaller runtimes for specific applications.

That last point is where tools like `jlink` enter the story, but it is better saved for a later post, once the basics are anchored.

## So why Project Jigsaw?

Now we can answer the original "why" without hand-waving.

Java had packaging and namespacing. It did not have platform-enforced boundaries.

Project Jigsaw exists to make modularity:

* Declarative, so the platform can see your intent.
* Verifiable, so tools can reason about your dependency graph.
* Enforceable, so "internal" actually means internal.

It turns modularity from a cultural norm into a constraint you can build against.

That is the difference between "please do not touch" and "the door is locked."

