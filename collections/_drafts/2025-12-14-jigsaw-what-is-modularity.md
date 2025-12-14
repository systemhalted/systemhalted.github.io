---
layout: post
title: Project Jigsaw (JPMS) – Part 1: What is Modularity?
draft_date: 2016-08-31
type: post
published: false
comments: true
status: draft
categories:
  - Technology
  - Software Engineering
tags:
  - java
  - jdk9
  - project-jigsaw
  - jpms
  - modularity
description: A practical definition of modularity in Java, and why Jigsaw existed even though we already had packages and JARs.
---

## A note from the future

I began this post in 2016, when Java 9 was still unreleased and Project Jigsaw felt like an approaching weather system. Java 9 eventually shipped (in 2017), and the module system became real, imperfect, and surprisingly educational.

This post keeps the original question intact: **what is modularity**, really, and why did Java need the platform itself to care?

## Java already had "modules"… right?

For the past few years, Java has evolved quickly, mostly for the better. JDK 8 changed everyday Java with lambdas and streams, making a more functional style feel native instead of like cosplay.

Then came JDK 9 and Project Jigsaw (JPMS, the Java Platform Module System). The obvious objection was, and still is:

Java already has JARs. Enterprise Java has WARs and EARs. Source code has packages and access modifiers. So why add "modules" at all?

To answer that, we need to be annoyingly precise about what a *module* is.

## What is a module?

A module is not just "a bunch of related code." That definition is so generous it would make my `Downloads/` folder a module, and it absolutely should not be trusted with responsibility.

A better definition:

A **module is a unit with an enforceable boundary**.

In practice, a module needs (at least) these traits.

### 1. Encapsulation (a hidden interior)

Encapsulation is the right to say: "this part is implementation detail; do not touch."

Java supports encapsulation via access modifiers (`private`, package-private, `protected`, `public`) and via packages. In the POJO world, we keep fields `private` and expose behavior through methods so nobody can accidentally mutate internal state and then act surprised when physics happens.

But here’s the catch:

Packages are excellent **organizing units**, but by themselves they are not **deployment boundaries**.

Once code is on the classpath, it tends to behave like a single sprawling neighborhood where everyone can wander into everyone else’s backyard, sometimes through reflection, sometimes through "it was convenient," sometimes through sheer dependency gravity.

### 2. A public surface (an intentional API)

A module must have a public surface: a set of types meant to be used by outsiders.

This matters because modularity is not just hiding. It is also *communicating on purpose*.

When modules interact, they should do so through the exported API, not through accidental knowledge of internals. This is how systems remain refactorable without becoming brittle.

So far, this sounds like "write disciplined code," which is true… and still not the full story.

The painful question is: can the platform help **enforce** that discipline?

## Why packages and JARs were not enough

Packages and JARs let us *aspire* to modularity. They don’t consistently let us *enforce* it.

Here are the classic failure modes that show up as systems grow.

### The classpath is a soup

The classpath is wonderfully simple and brutally permissive. Put things on it, and they exist. This is great for getting started, and occasionally terrible