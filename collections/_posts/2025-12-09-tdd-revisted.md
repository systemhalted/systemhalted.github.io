---
layout: post
title: TDD as a Management Technique Revisited
category:
- Software Engineering
tags:
- software
- leadership
- management
comments: true
toc: true
description: I still think TDD is a Taylorian construct. What I care about now is thinking about testing and evaluation before writing code.
---

In an earlier post I argued that **Test Driven Development is fundamentally a management technique**. Not a path to better design, not a guarantee of fewer bugs. It is a Taylorian construct, and its main achievement is that it forces people to write unit tests.

I still believe that.

What has changed is that I now care less about TDD the ritual and more about the habit underneath it. Thinking about testing and evaluation before writing code is valuable, and not just at the unit level. It matters at the functional, component, and integration levels too. The ritual is Taylorism. The mindset is design.

## Version 1: TDD as Taylorism

Unit tests are good. They reduce maintenance costs, prevent regressions, and give us courage to refactor.

The problem is human, not technical. Left alone, many teams will not write enough tests. Even when they do, tests are an afterthought, written just before merge or not at all. Management wants fewer bugs and lower maintenance cost but cannot directly measure future headaches avoided.

TDD turns "write tests" into a visible, enforceable step:

1. Write a failing unit test
2. Make it pass
3. Refactor
4. Repeat

That loop is measurable. You can ask whether the developer wrote tests first, whether the build is green, and what the coverage is. That is classic Taylorism: break work into small steps, make them observable, then control them. TDD is not a design religion. It is management plumbing for test-writing behavior.

That framing explains why TDD took off in large organizations obsessed with metrics. But it is incomplete.

## What changed: from ritual to evaluation

Even in teams that never practiced pure TDD, the best engineers did a version of the thinking behind it. They imagined failure modes, thought about inputs and outputs, and cared about how their work would be evaluated, not just whether it compiled. That is not TDD. That is good engineering.

So my view shifted. TDD as ritual is still a Taylorian construct, but test-first thinking, in the broader sense, is something you want almost everywhere. The mistake is to shrink test-first down to unit tests only and treat everything else as a side quest.

The real question is larger: before we add this behavior to the system, how will we know it works, at every relevant level? Once you phrase it that way, you are pushed beyond unit tests.

## Four levels of thinking before you code

I do not mean "write a unit test file before a class file" and declare victory. I mean something more layered.

### 1. Functional: what would convince a user?

Imagine a skeptical product partner or end user next to you. What would convince them the feature works in their world? That question leads to example flows ("a customer with X, who does Y, should see Z"), edge scenarios ("what if the user loses connectivity halfway through"), and policy constraints ("what are we allowed to do").

This is the territory of acceptance or functional tests. You do not need a test framework to start. A one-page doc with concrete examples is already test-first thinking at the functional level.

### 2. Component: what contract does this service promise?

For any service or module, ask what contract you are promising to the rest of the system, what you guarantee about behavior, latency, and failure modes, and how other teams will know you broke something. These questions give rise to component or API-level tests.

Designing them early reveals awkwardness: "why are there three ways to call this?", "what happens if the downstream is slow but not down?", "do we retry, for how long, with what backoff?". We have not written a single test method yet. We are still shaping the surface area of the system.

### 3. Integration: how does this behave in the real ecosystem?

The third level involves databases, message queues, third-party APIs, authentication, caches, and time. Integration thinking asks whether the system can survive real data rather than happy-path fixtures, what happens when the schema changes, and how it behaves when a dependency is briefly unavailable.

You may not be able to write full integration tests before code exists. But if you do not think about them early, you will design a system that only works in your unit test universe. Many nice designs fail this way in production.

### 4. Unit: what invariants must always hold?

At this level the questions are granular. What assumptions must never be violated inside this function or class? What bug would be annoying to debug in prod? Which branches are easy to forget?

Unit tests enforce local invariants and give you courage to refactor internals. They are not sufficient to guarantee the system does what you think, but they are a crucial layer in the overall evaluation story.

The order of thought matters. You do not start from "how do I hit 85 percent coverage". You start from "what does success look like at each level" and let tests follow.

## TDD as a management tool, test-first as a design habit

I still see TDD, as originally popularized, as a management-friendly practice. It decomposes work into repeatable, measurable steps, helps organizations enforce test-writing, and pairs nicely with coverage dashboards and pipeline gates.

None of that is bad. In large systems with many teams, some enforcement is necessary, otherwise tests are the first thing sacrificed under pressure. The problem is when the enforcement mechanism becomes the goal: coverage numbers turn into performance proxies and green builds turn into the scoreboard. Meanwhile nobody asks whether we are testing the right things at the right levels, whether our tests reflect how the system is really used, or whether we over-invest in unit tests and under-invest in integration and functional evaluation.

That is the shift I care about. Tests as management control are useful but limited. Tests as design and evaluation tools are essential, and much broader than TDD usually admits.

## So what do we actually do differently?

First, for any non-trivial feature, write down how we will know this works before someone opens the IDE. Not a 20-page spec. A short checklist:

- Key functional scenarios that must work
- User-facing behavior we care about (latency, error messages, data correctness)
- Critical integration points and their expectations
- A couple of nasty edge cases we are afraid of

Second, think in layers of evaluation. When a design is proposed, ask what the acceptance tests are even if they are manual, what API or component tests will protect other teams, what integration tests will keep us honest about reality, and where unit tests provide value versus where they are just coverage padding.

Third, be explicit about where TDD fits. If a team finds "write a failing unit test, then code" helpful, let them use it. Just do not confuse the ritual with the outcome. The outcome is a clear shared understanding of success, tests at the right levels to guard it, and the ability to change the system with confidence. Whether that came from strict TDD, loose test-first thinking, or some other workflow is secondary.

## Closing the loop

My old self was right about one thing. TDD has a strong Taylorian flavor. It is a management technique that emerged to tame the chaos of software development and make test-writing more predictable.

But the valuable instinct is not "thou shalt always write tests first". It is this: before I add behavior to a complex system, I should be clear about how that behavior will be evaluated, at the functional level, the component boundary, the integration seam, and inside the unit. You can reject TDD as religion and still keep that instinct.
