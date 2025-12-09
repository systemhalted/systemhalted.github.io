---
layout: post
title: TDD as a Management Technique Revisited
category: [Software Engineering, Management]
tags: [TDD, Testing, Management, Software Design]
comments: true
summary: I still think TDD is a Taylorian construct. But I now care less about the ritual and more about a deeper idea: thinking about evaluation and testing before we write code.
---

In an earlier post I argued that **Test Driven Development is fundamentally a management technique**.

Not a mystical gateway to “better design”.  
Not a guarantee of fewer bugs.  
A Taylorian construct whose main achievement is simple: it forces people to write unit tests.

I still believe that.

What has changed is this:  
I now care less about _TDD the ritual_ and more about the broader habit hiding underneath it.

Thinking seriously about **testing and evaluation before writing code** is valuable.  
Not just at the unit level, but at the **functional, component, and integration** levels too.

The ritual can be Taylorism.  
The mindset is design.

## Version 1: TDD as Taylorism

Let me quickly restate the original thesis.

Unit tests are good. They reduce maintenance costs, prevent regressions, and give us courage to refactor.

The problem is human, not technical:

1. Left alone, many teams will not write enough tests.
2. Even when they do, tests are often an afterthought, written just before merge, or not at all.
3. Management wants fewer bugs and lower maintenance cost, but cannot directly measure “future headaches avoided”.

Enter TDD.

TDD turns “write tests” into a **visible, enforceable step**:

1. Write a failing unit test  
2. Make it pass  
3. Refactor  
4. Repeat  

That loop is eminently measurable.

You can ask:

- Did the developer write tests first  
- Is the build green  
- What is the code coverage  

That is classic Taylorism: break down work into small steps, make them observable, then control them.

From that angle, TDD is not a design religion.  
It is **management plumbing** for test-writing behavior.

I still find that framing useful. It explains why TDD took off in large organizations obsessed with metrics and “best practices”.

But it is incomplete.

## What changed: from ritual to evaluation

Over time I noticed something awkward.

Even in teams that never practiced “pure TDD”, the best engineers tended to do a version of the _thinking_ behind it:

They imagined failure modes before they wrote code.  
They thought about inputs and outputs.  
They mentally ran scenarios in their heads.  
They cared about how their work would be evaluated, not just how it would compile.

That is not uniquely “TDD”.  
That is just **good engineering**.

So my view shifted:

- TDD-as-ritual is still a Taylorian construct.
- But **test-first thinking**, in a broader sense, is something you want almost everywhere.

The mistake is to shrink “test-first” down to “unit tests only” and treat everything else as a side quest.

The real question is larger:

> Before we add this behavior to the system, how will we know it works?  
> At every relevant level.

Once you phrase it that way, you are automatically pushed beyond unit tests.

## Four levels of thinking before you code

When I say “think about testing and evaluation before writing code”, I do not mean “write a unit test file before a class file” and declare victory.

I mean something more layered.

### 1. Functional: what would convince a user?

Start at the top.

Imagine a reasonably skeptical product partner or end user sitting next to you. What would convince them that this feature actually works in their world?

That question leads to things like:

- Example flows: “A customer with X, who does Y, should see Z.”
- Edge scenarios: “What if the user loses connectivity halfway through?”
- Policy constraints: “What are we allowed or not allowed to do?”

This is the territory of **acceptance or functional tests**.

You do not need a test framework to start. Even a one-page doc with concrete examples is already “test-first thinking” at the functional level.

### 2. Component: what contract does this service promise?

Next layer down: the component boundary.

For any service or module, ask:

- What contract am I promising to the rest of the system  
- What do I guarantee about behavior, latency, and failure modes  
- How will other teams know we broke something  

These questions give rise to **component or API-level tests**.

Designing them early tends to reveal awkwardness:

- “Why are there three ways to call this?”
- “What happens if the downstream is slow but not down?”
- “Do we retry? For how long? With what backoff?”

Note that we have not yet written a single “public void testSomething()”. We are still shaping the **surface area** of the system.

### 3. Integration: how does this behave in the real ecosystem?

The third level is where reality barges in.

Databases. Message queues. Third-party APIs. Authentication. Caches. Time.

Integration thinking asks:

- Can this survive real data, not just happy-path fixtures?
- What happens when the schema changes?
- What if Kafka is briefly on fire?

You might not be able to write full integration tests before any code exists. But if you do not think about them early, you will unconsciously design a system that only works in your unit test universe.

This is where many “nice” designs die in production.

### 4. Unit: what invariants must always hold?

Finally, the part everybody talks about: unit tests.

At this level, the questions are more granular:

- What assumptions must never be violated inside this function or class? 
- What bug would be extremely annoying to debug in prod?
- Which branches are easy to forget about?  

Unit tests are excellent at enforcing **local invariants** and giving you courage to refactor internals.

They are not sufficient to guarantee that the **system** does what you think it does. But they are a crucial layer in the overall evaluation story.

The important bit is the order of thought:

You do not start from “how do I hit 85 percent coverage”.  
You start from “what does success look like at each level” and let tests follow.

## TDD as a management tool, test-first as a design habit

This is where I have landed:

I still see TDD, as originally popularized, as a management-friendly practice:

- It decomposes work into simple, repeatable, measurable steps.
- It helps organizations enforce test-writing behavior.
- It pairs nicely with coverage dashboards and pipeline gates.

Nothing about that is inherently bad. In large systems with many teams, **some** enforcement is necessary. Otherwise tests are the first thing sacrificed under pressure.

The problem is when **the enforcement mechanism becomes the goal**.

“We do TDD here” becomes identity theatre.  
Coverage numbers become performance proxies.  
Green builds become the scoreboard.

Meanwhile, nobody is asking basic questions:

- Are we testing the right things at the right levels?
- Do our tests reflect how the system is really used?
- Are we over-investing in unit tests while under-investing in integration and functional evaluation?

That is the shift I care about.

I now treat:

- **Tests as management control**: useful, but limited.  
- **Tests as design and evaluation tools**: essential, and much broader than TDD usually admits.

## So what do we actually do differently?

This all sounds very philosophical, so let me anchor it in a few concrete habits.

First, for any non-trivial feature, write down **“how we’ll know this works”** before someone opens the IDE.

Not a 20-page spec. A short, sharp checklist:

- Key functional scenarios that must work  
- Any user-facing behavior we care about (latency, error messages, data correctness)  
- Critical integration points and their expectations  
- A couple of nasty edge cases we are afraid of  

Second, encourage teams to think in **layers of evaluation**.

When a design is proposed, ask:

- What are the acceptance tests, even if they are manual  
- What API or component tests will protect other teams from our changes  
- What integration tests will keep us honest about reality  
- Where do unit tests actually provide value, and where are they just “coverage padding”  

Third, be explicit about where TDD fits.

If a team finds “write a failing unit test, then code” helpful to structure their work, great. Let them use it.

Just do not confuse the **ritual** with the **outcome**.

The outcome is:

- We have a clear, shared understanding of success.  
- We have tests at the right levels to guard that success.  
- We can change the system with confidence.

Whether that came from strict TDD, loose test-first thinking, or some other workflow is secondary.

## Closing the loop

So yes, my old self was right about one thing:

TDD has a strong Taylorian flavor. It is a management technique that emerged to tame the chaos of software development and make test-writing behavior more predictable.

But if I stop there, I miss the deeper point.

The valuable instinct is not “thou shalt always write tests first”.  
The valuable instinct is:

> Before I add behavior to a complex system, I should be very clear about how that behavior will be evaluated.

At the functional level.  
At the component boundary.  
At the integration seam.  
Inside the unit.

You can reject TDD-as-religion and still embrace that instinct.

In fact, if you care about real systems in the real world, you probably should.