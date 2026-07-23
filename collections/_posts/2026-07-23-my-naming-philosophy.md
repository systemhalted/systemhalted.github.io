---
layout: post
title: My Naming Philosophy
date: 2026-07-23 02:00:00 -0500
categories:
- Software Engineering
- Computer Science
tags:
- naming
- api-design
- java
- design
- software
comments: true
toc: true
description: 'The rules I follow when naming variables, API fields, and schema elements. Most of it is borrowed from Kent Beck, Strunk, and Russ Cox; the rest is how I read their rules when the thing being named is a variable rather than a design.'
---

I spend more time on names than on most other parts of writing code. Not because a well-chosen name is pleasant to read, though it is, but because naming forces the same decisions that design does: what it is, what it holds, who it is for. When I cannot name something, it is usually because I have not decided what it is yet.

My rules for naming have settled into a small set over the years. The core is [Kent Beck's four rules of simple design](https://martinfowler.com/bliki/BeckDesignRules.html): passes the tests, reveals intention, no duplication, fewest elements. Beck stated them for a design as a whole. I find they apply, almost without translation, to naming a variable in code or a field in an API schema. The rest comes from Strunk's *The Elements of Style* and a short piece by Russ Cox. Here is how I read each rule when the thing being designed is a name.

## Runs the tests

A declaration is a claim about what a variable will hold, and the type is the only part of that claim anything ever checks. The type should be able to test the value the variable must hold. Not everything is a `String`.

```java
String email;   // nothing checks that this is an email
Email email;    // construction fails unless the value parses
```

A bare `String` passes every possible value, which means it tests nothing. An `Email` type that validates in its constructor turns every assignment into a test, and that test also runs in production, on every value the field receives. The same holds in an API definition: `type: string` promises nothing, while `format`, `enum`, `pattern`, and range constraints are the schema's way of testing values before they reach your code. I wrote earlier about [where types end and tests begin](/2026/06/21/types-check-shape-tests-check-behaviour/); this is the naming-side consequence. Choosing a type is part of choosing a name, because both are claims about the value.

## Reveals intention

The variable in code and the field in an API or schema must say what it is for. If a reader has to look at usages to work out what a field means, the name has failed. This matters even more in an API than in code, because the consumer of a schema cannot read your implementation. They have the name, the type, and whatever description you wrote, and most will read no further than the name.

## No duplication

A name should not repeat what its surroundings already say. `order.orderId` says *order* twice; inside an `Order`, the field is just `id`. Suffixes like `Value`, `Flag`, `String`, and `Data` repeat the type, and the type is already visible in the declaration. I made the same argument about `Request` and `Response` suffixes on API models in [Vibe Coding and the Baby Genius Problem](/2025/12/15/vibe-coding-and-baby-genius/). Say everything once, and only once -- that holds for the words inside a name as much as for the code around it.

## Fewest elements

Define only what you need. Once a field is in a schema, consumers start depending on it, and removing it becomes a breaking change. A field added because someone might need it later still has to be named, documented, validated, and migrated, without any current use to justify that work. If nothing reads it today, leave it out.

## Omit needless words

Strunk's [rule 13](https://www.bartleby.com/lit-hub/the-elements-of-style/iii-elementary-principles-of-composition/#13) says a sentence should contain no unnecessary words. Applied to a name: `customerEmailAddressString` contains one useful word. `String` repeats the type, `Address` repeats what *email* already implies, and what remains after striking them is `customerEmail` -- or, inside a `Customer`, just `email`.

## Length follows scope

Russ Cox [puts it](https://research.swtch.com/names) as: a name's length should not exceed its information content. A loop index that lives for three lines is `i`, and making it `loopIndexCounter` adds letters without adding information. A public field, read far from its declaration by people who never see the surrounding code, has to carry more.

These rules usually agree. When they conflict, I pick whichever name is easier for the reader. In a follow-up post I will take a badly named API model and apply these rules to it one pass at a time.
