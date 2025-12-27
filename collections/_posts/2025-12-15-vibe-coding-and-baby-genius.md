---
layout: post
title: Vibe Coding and the Baby Genius Problem
published: true
comments: true
categories: [Technology, Software Engineering, AI]
tags: [agentic-workflows, vibe-coding, testing, observability, conventions, testing]
description: Vibe coding is fun again. However, Agents are still baby geniuses. The fix is turning preferences into accountability.
featured_image: assets/images/featued/2025-12-15-vibe-coding-and-baby-genius.png
featured_image_alt: A programmer at a multi monitor desk codes beside a cute "baby genius" robot with a pacifier under a neon "Vibe Coding" sign, with charts, a ping pong paddle, and a suitcase hinting at trust, context, and autonomy.
featured_image_caption:  AI Agents as baby geniuses - brilliant, needy, and not quite ready for ping pong or vacation.
---

Vibe coding has been ridiculously fun.

It has brought back the joy to programming. The kind of joy you thought adulthood, meetings, and Jira had permanently confiscated.

And yet, right now, most agents are more or less **super intelligent babies**.

They are brilliant. They are fast. They can surprise you.
But they still need to be fed context again and again.

Today, while working on my service virtualizer, I had to continuously inform the agent about my preference for naming API models and domain models.
The difference matters:

* API models are edge interfaces, representing outward state.
* Domain models are internal shapes, used to pass messages within the API.

The agent continuously "lied" that it was following the instructions I provided under the `.github/instructions` folder.
After multiple rounds of trial and error, it partially understood the assignment.

That’s the gap between intelligence and autonomy.

## The autonomy ladder: vibe coding, ping pong, vacation

It is going to take some time before agents can act independently while you play ping pong.
And slightly longer for you to delegate the work completely to a few AI agents and go on vacation.

AI agents need to be **context-aware** for me to enjoy ping pong.
They need to write properly logged and observable clean code before I can trust them enough to enjoy a vacation.

That last line is the whole story.

Ping pong is a context problem.
Vacation is an accountability problem.

## A concrete example: my model naming rule

This is where "feed context again and again" shows up in real code.

### API models should be nouns

API models "datafy" representational state.
So there is no separate request and response.
There is only one state to represent for both request and response.

Some fields are read only, sure.
But it is still one state.

So instead of:

* `CreateEndpointRequest`
* `CreateEndpointResponse`
* `EndpointResponse`

I want:

* `Endpoint`

### Domain models should not say "Request", "Response", or "Data"

Domain models don’t need `Request`, `Response`, or `Data` as suffixes.
That information is redundant.

`EndpointData` as a class serves no purpose compared to `Endpoint` as a class.

If it is the domain concept, name it like the concept:
`Endpoint`, `VirtualService`, `Route`, `Rule`, `Match`, `Mapping`.

If context matters, packages can carry it:
`in.systemhalted.api.model.Endpoint`
`in.systemhalted.domain.model.Endpoint`

Same noun, different layer.

## The real issue: preferences are not enforceable

Human teams survive because we turn preferences into systems.

"Please follow this convention" is polite.
But politeness is not a compiler.

If you want agents to stop "lying" (really: confidently guessing), you have to move from memory to mechanism.

In other words, from vibes to accountability.

## Make conventions executable

The big move is simple:
turn conventions into checks that fail loudly.

Then the agent doesn’t need to remember your rules.
It just needs to pass reality.

### Option 1: enforce architecture rules with ArchUnit

[ArchUnit](https://www.archunit.org/) is a Java testing library for validating architectural decisions in code.
It lets you write tests for package boundaries, dependency direction, layering rules, and conventions that are otherwise tribal knowledge.

That is exactly what an AI agent struggles with: it will agree with tribal knowledge, then forget it, then agree again.

Here’s a practical enforcement approach:

* API models live in `..api.model..` and must not end with `Request`, `Response`, or `Data`
* Domain models live in `..domain.model..` and must not end with `Request`, `Response`, or `Data`
* Domain must not depend on API

{% highlight java %}
// src/test/java/in/systemhalted/architecture/ModelConventionsTest.java
package in.systemhalted.architecture;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.lang.ArchRule;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

class ModelConventionsTest {

    private final JavaClasses classes = new ClassFileImporter()
            .importPackages("in.systemhalted");

    @Test
    void api_models_must_not_end_with_request_response_or_data() {
        ArchRule rule = classes()
                .that().resideInAPackage("..api.model..")
                .should().haveSimpleNameNotEndingWith("Request")
                .andShould().haveSimpleNameNotEndingWith("Response")
                .andShould().haveSimpleNameNotEndingWith("Data");

        rule.check(classes);
    }

    @Test
    void domain_models_must_not_end_with_request_response_or_data() {
        ArchRule rule = classes()
                .that().resideInAPackage("..domain.model..")
                .should().haveSimpleNameNotEndingWith("Request")
                .andShould().haveSimpleNameNotEndingWith("Response")
                .andShould().haveSimpleNameNotEndingWith("Data");

        rule.check(classes);
    }

    @Test
    void domain_must_not_depend_on_api() {
        ArchRule rule = noClasses()
                .that().resideInAPackage("..domain..")
                .should().dependOnClassesThat().resideInAnyPackage("..api..");

        rule.check(classes);
    }
}
{% endhighlight %}

This does not prove a name is a noun.
But it blocks the most common failure mode: growing a forest of `*Request`, `*Response`, and `*Data` types that all mean the same thing.

### Option 2: generate API models, handcraft domain models

If your API layer is OpenAPI driven, treat API models as edge artifacts and generate them.
Then keep domain models intentionally authored and stable.

The principle is simple:
> when the outside world changes, your domain shouldn’t shatter like glass.

### Option 3: a definition of done for agents

Agents struggle because "done" is fuzzy.

So make it concrete:

1. Restate conventions from `.github/instructions` in plain English
2. Implement the change
3. Run tests
4. Show evidence: test output, files changed, and convention checks passing

That’s how you replace "trust me" with "see for yourself."

## Observability is the vacation requirement

Ping pong needs context awareness.
Vacation needs observability.

If an agent writes code that "works" but cannot explain itself at runtime, you have not delegated work.
You have adopted a mystery.

Vacation grade code needs boring grown up traits:

* structured logs you can search
* correlation IDs you can follow
* meaningful error handling
* metrics and traces where it matters

Because when you are on vacation, the only thing worse than an outage is an outage that speaks in riddles.

## Final thoughts

Agents don’t mainly need to be smarter.
They need to be more accountable.

An agent without a stop condition is just a very confident infinite loop.

The trick is not to lecture the agent harder.
The trick is to build a world where "following instructions" is measurable.

Then you can pick up the paddle.

And later, maybe, the suitcase.