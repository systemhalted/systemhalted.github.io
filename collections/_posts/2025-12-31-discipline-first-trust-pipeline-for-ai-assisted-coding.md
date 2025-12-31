---
layout: post
title: "Discipline First: A Trust Pipeline for AI-Assisted Coding"
date: 2025-12-31
type: post
published: true
comments: true
categories:
  - Technology
  - Software Engineering
tags:
  - ai-assisted-coding
  - agentic-coding
  - vibe-coding
  - extreme-programming
  - xp
  - tdd
  - continuous-integration
  - testing
  - guardrails
  - engineering-discipline
featured_image: assets/images/featured/2025-12-31-discipline-first-trust-pipeline-for-ai-assisted-coding.png
featured_image_alt: Illustration of a human and an AI collaborating at a laptop beside a colorful pipeline labeled "Brief," "Guardrails," "Tests," and "Ship," each with a checkmark, ending in a rocket launch to represent reliable delivery.
featured_image_caption: Discipline First: a trust pipeline for AI-assisted coding, where briefs, guardrails, and tests turn speed into shippable software.
description: "AI-assisted coding is a force multiplier. This post argues that disciplined engineering practices, rooted in Extreme Programming, are what make agentic workflows trustworthy and shippable."
---

Vibe coding is not a software engineering paradigm. It’s a mood. Engineering is what makes it ship.

My core claim is simple: engineers who set up a task with clear instructions, a thin prototype, and hard guardrails tend to have a better experience with AI-assisted coding, and they tend to keep their good faith in the tools. Engineers who don’t, often walk away with confusion, rewrites, and a lingering sense that the agent is "untrustworthy." And that’s why the same tool creates opposite stories, depending on who’s holding it.

This post is my framework, **Discipline First: a trust pipeline for AI-assisted coding**. It’s a small kit you can use immediately: an Agent Brief that makes intent hard to misread, guardrails that make failures visible early, and a one-week experiment that turns belief into evidence.

## The axis that matters

The agent isn’t the methodology. Your engineering habits are.

I’m going to be deliberately boring about definitions, because the labels are less important than the axis. Whether you call it vibe coding, agentic coding, or AI-assisted coding, the same split shows up: disciplined delivery versus undisciplined delivery. The tools can draft code, refactor code, even propose architectures, but they can’t rescue a vague task from its own vagueness.

Discipline is what turns "the agent wrote something" into "the system changed, and we can explain why, prove it works, and undo it safely if it doesn’t."

## Four engineers walk into the same tool

And once you see it that way, four kinds of engineers show up around AI-assisted coding.

The **Skeptic** is driven by quality, security, and maintainability. They are not anti tool. They are pro standards. They will try these tools in a sandbox, or allow them under strict review, and they trust what they can validate through time-tested discipline: tests, contracts, architecture checks, and clean interfaces. Their posture is "prove it," and their lingering doubt is usually about authorship. They suspect only human engineers can reliably meet that bar.

The **Dismisser** opts out early. Sometimes that’s reflexive, sometimes it’s reasoned: they’ve seen bad suggestions, security risks, legal uncertainty, vendor lock-in, or unreviewable diffs and they decided the trade is not worth it. Their posture is still "already decided," but the *why* matters. You don’t convert a Dismisser by arguing about models or demos. You convert them by giving them control of the bar: let them define the quality gates, then run a small, measured experiment in their own codebase that either meets the bar or fails honestly.

The **Viber** loves speed. They ship fast, accept large diffs, and skip the guardrails that make code testable and observable. Their posture is "speed is truth." To be fair, that posture has a place: spikes, prototypes, throwaway demos, learning a new stack. The problem is when the same vibe crosses the border into production. That’s where "it seems to work" quietly becomes regressions, mystery failures, and eroded trust. The point of Discipline First is not to shame exploration. It’s to prevent avoidable damage when the stakes are real.

The **Disciplined Builder** loves AI-assisted coding and still engineers hard. Small tasks, small diffs, acceptance criteria, tests, verification loops, rules files, and a security mindset. They do not care whether the code was written by a human or an agent. They care that it is explainable, reviewable, testable, and observable. Their posture is simple: trust is built.

The only difference between the Skeptic and the Builder is what they believe about that last mile. The Skeptic thinks only humans can deliver it consistently. The Builder has learned how to make the agent earn it.

## Discipline First is XP with a faster pair

Discipline First is not a new religion. It is **Extreme Programming** adapted to a world where your pair can write code at absurd speed. Extreme Programming starts with **Values**, because Values guide **Principles**, and Principles are what make **Practices** hold up under pressure.

The Values are **Communication, Simplicity, Feedback, Courage, and Respect**.

Communication becomes explicit intent: the Agent Brief and rules files are how you communicate without mind reading. Simplicity becomes a principle you enforce: assume simplicity, slice work into small tasks, keep diffs small, keep releases small. Feedback becomes rapid and objective: failing tests and continuous integration tell the truth early. Courage becomes disciplined restraint: stop the agent when it starts guessing, delete generated code when it bloats, and ship in increments so reality can correct you fast. Respect becomes engineering for humans: keep standards non negotiable, make changes transparent, and leave behind code that future people can understand, test, observe, and safely change.

From those Values and Principles, the Practices follow naturally: pair programming with the agent as the pair and the human as the driver, test driven development as the spec the agent must satisfy, continuous integration as the always on referee, and small releases as the safest way to turn speed into reliability.

## The Discipline First kit

### 1) The Agent Brief

Think of the Agent Brief as a PRD that’s small enough to fit in your head, but sharp enough that the agent can’t "creatively interpret" it.

1. Goal  
2. Non-goals  
3. Constraints  
4. Interfaces  
5. Acceptance criteria  
6. Risks  
7. Test plan  
8. Observability  
9. Dependencies  
10. Recovery and blast radius  

Here’s a concrete example (for one service):

**Goal:** Add rate limiting to `POST /payments` to reduce abuse and protect downstream dependencies.  
**Non-goals:** No UI changes. No new auth scheme. No changes to other endpoints.  
**Constraints:** Must not change the public API contract. Must keep p95 latency impact under 5%.  
**Interfaces:** `POST /payments` only; configuration via env var `PAYMENTS_RATE_LIMIT_RPS`.  
**Acceptance criteria:** Requests above limit return `429` with standard error body; limits are per-customer; logs include rate-limit decision.  
**Risks:** False positives blocking legit traffic; misconfigured limits; uneven behavior across instances.  
**Test plan:** Add functional tests for 200, 429, and boundary conditions; include concurrency test; all tests deterministic in CI.  
**Observability:** Emit metric `payments.rate_limited.count`; structured log `rate_limit_decision` with customer id hash; dashboard alert on spikes.  
**Dependencies:** Redis (or in-memory) limiter library already approved; no new infrastructure.  
**Recovery and blast radius:** Feature flag the limiter; default off; rollback is flag flip; document emergency disable procedure. 

Then three hard rules.

1. Do not change public APIs unless explicitly permitted.  
2. Prefer the smallest diff that can satisfy the brief.  
3. Stop and ask when uncertain.

### 2) Guardrails

Not vibes. Guardrails.

Unit tests and functional tests. Contract checks. Architecture checks. Code review. Small tasks. CI as referee.

If an agent can ship code faster than a human, your only sane response is to make the truth show up faster than the code. We have already seen public "trust cliff" moments when autonomy meets weak guardrails.[^incident]

Small diffs are not about being precious. They are about control. A small change is easier to review, easier to reason about, easier to test, and easier to roll back. Agents tend to expand scope unless you constrain them, so "small diffs" is both a safety boundary and a way to keep context from exploding.

### 3) Durable instructions

Modern agentic tooling is quietly reinventing the same old idea: durable project instructions.

Rules files in agentic IDEs make behavior persistent across prompts.[^rules]  
Repo-level instruction files like AGENTS.md make "how to behave here" predictable.[^agents]  
For conventions that should survive editors and IDEs, EditorConfig gives you portable, version controlled style rules.[^editorconfig]

Practical rule of thumb:

Use EditorConfig for formatting and style that must survive editors and IDEs.  
Use Rules files for tool-specific behavior. What to include in context, how to respond, what not to touch.  
Use AGENTS.md for repo-wide agent behavior. Setup commands, test commands, conventions, safety boundaries.

If you only do one thing, do AGENTS.md plus your Agent Brief template. That creates a stable baseline even when prompts change.

## A one-week experiment (tests only)

Pick one service. Pick one real user workflow in that service. Then write missing functional tests until the behavior is pinned down.

You will know it’s working when:

The tests fail for the wrong behavior and pass for the right behavior.  
They run repeatedly without flakes.  
They do not depend on environment quirks or real external systems.  
CI stays green and the suite stays fast enough to run often.  
Any production code change made only for testability is small and justified.  
A human reviewer can read the tests as a spec and agree they capture real behavior.

Measure the boring things: how many rewrites the agent needed, how many times you had to restate intent, how large the diffs got, how much review effort it took, and how quickly you got to "tests green."

## When Discipline First is overkill (and when it breaks)

Discipline First is the safest on ramp for production work. It is not mandatory ceremony for everything.

It is overkill for throwaway prototypes, exploratory spikes, and one-off scripts where the cost of failure is low and the code has no future. In those contexts, "vibes first" can be a valid way to learn quickly.

Discipline First breaks down in predictable ways:

The Brief rots. Intent changes but the kit does not.  
Tests become performative. They pass but don’t pin behavior.  
Guardrails turn into friction without signal. Slow, flaky, or mis-scoped checks.  
The agent is allowed to widen scope. Diffs balloon, review becomes theater.

The fix is the same as always: tighten the slice, keep the checks honest, and scale the process to the risk.

## Why measure at all

Because productivity gains are not guaranteed.

One of the clearest public data points so far is a randomized controlled trial from METR (published July 2025) studying experienced open source developers working in codebases they already knew. When AI tools were allowed, developers expected big speedups and later felt faster, but measured completion time was slower on average in that setting.[^metr]

That result does not mean "AI slows everyone down." Tools and workflows change fast, task types vary wildly, and many teams report real gains. It means your intuition is not an instrument. Discipline First is not "trust the agent." It’s "instrument the work."

## Close the loop for each persona

For the Skeptic: run one Discipline First experiment on tests only in a sandboxed branch.

For the Dismisser: pick one internal task, define your own quality gates, and let the experiment decide.

For the Viber: no big diffs, and every change must come with a failing test first.[^tdd]

For the Builder: make discipline the default--publish the Agent Brief template, standardize rules files, and optimize the workflow so the safest path is the easiest path.

## Sources

[^rules]: Cursor Rules documentation.
[^agents]: OpenAI Codex guidance for AGENTS.md.
[^editorconfig]: EditorConfig specification and IDE support docs.
[^metr]: METR RCT on experienced open-source developer productivity with early-2025 AI tools.
[^tdd]: Kent Beck’s test-first discipline (red-green-refactor).
[^incident]: Public reporting and statements on a July 2025 Replit incident, used here as a cautionary example of autonomy without guardrails.

{% highlight text %}
Cursor Rules
- https://cursor.com/docs/context/rules

AGENTS.md (OpenAI Codex)
- https://developers.openai.com/codex/guides/agents-md/
- https://openai.com/index/introducing-codex/

EditorConfig
- https://editorconfig.org/
- https://spec.editorconfig.org/
- https://www.jetbrains.com/help/idea/editorconfig.html

METR study (productivity not guaranteed)
- https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/
- https://arxiv.org/abs/2507.09089
- https://www.reuters.com/business/ai-slows-down-some-experienced-software-developers-study-finds-2025-07-10/

TDD reference (test-first, red-green-refactor)
- https://martinfowler.com/articles/is-tdd-dead/
- https://stanislaw.github.io/2016-01-25-notes-on-test-driven-development-by-example-by-kent-beck.html

Incident footnote (trust cliff example)
- https://www.businessinsider.com/replit-ceo-apologizes-ai-coding-tool-delete-company-database-2025-7
- https://www.tomshardware.com/tech-industry/artificial-intelligence/ai-coding-platform-goes-rogue-during-code-freeze-and-deletes-entire-company-database-replit-ceo-apologizes-after-ai-engine-says-it-made-a-catastrophic-error-in-judgment-and-destroyed-all-production-data
- https://x.com/amasad/status/1943062428929892384
{% endhighlight %}