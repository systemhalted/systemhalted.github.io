---
layout: post
title: "What Sits Underneath the Agent Loops Post"
date: 2026-07-03
categories:
- Technology
- Software Engineering
- AI
tags:
- ai
- agents
- claude-code
- engineering-management
comments: true
description: Anthropic's Claude Code team described four kinds of agent loops. Notes on where the check on the work lives in each, and on the artifacts a team has to make durable underneath them.
org_source: org/posts/2026-07-03-what-sits-underneath-the-agent-loops-post.org # generated file — edit the .org source
---
Anthropic's Claude Code team put out a [short piece](https://claude.com/blog/getting-started-with-loops) last week describing four kinds of agent loops: turn-based, goal-based, time-based, and proactive. Each type comes with a trigger, a stop condition, and typical use cases. The taxonomy describes surface. It says how the agent runs, how it stops, and what starts it. Underneath it sits a different question: where does the check on the work actually live? Each loop type puts that check in a different place, and the place that holds it is the place a team has to make durable before the next loop up is safe to build.

In a turn-based loop, the check lives in your judgement. The agent gathers context, does the work, checks itself, and hands back a result. You decide whether to accept it, redirect, or discard. Your judgement does not scale past a certain volume of work. What helps is writing the check down as something the agent can run before it comes back to you. Start the dev server, exercise the changed control, take screenshots before and after, run the affected tests. A skill file that encodes these steps moves the check from one person's head to a file the whole team can read and improve. Every loop above this one assumes that file exists.

A goal-based loop moves the check into the exit criterion. You state what done looks like, and an evaluator model tests the condition each time the agent tries to stop. A measurable criterion, such as a Lighthouse score or a latency threshold on a specific endpoint, stops the loop on something you can defend after the fact. A vague criterion stops the loop early, because the agent convinces itself it is done, or lets it run long, because there is no way to be sure. Most teams do not have exit criteria for their own work written in language a person could act on, let alone an agent. The first attempt at a goal-based loop usually exposes that gap.

With a time-based loop, the trigger carries the check. The same prompt runs every N minutes against the current state of the world: summarising a channel, sweeping a queue, checking a pull request for review comments. What usually breaks here is the interval, not the prompt. A short interval against a slow-moving source wastes tokens, and a long interval against a fast-moving source misses changes that need a response. When the source system can emit an event, such as a webhook or a queue depth alert, an event trigger ties each run to a change that actually happened. A time-based loop works better as a stage on the way to an event-driven one than as a destination.

A proactive loop spreads the check across the whole system around the agent. A routine watches a stream of bug reports, alerts, or tickets, and runs a goal-based loop for each item until someone turns it off. This is a queue consumer whose judgement comes from a model, so it needs the same properties as any production consumer: idempotency, rate limits, spend caps, observability, a shutoff, and an owner. The Anthropic post covers token budgeting and routing routine subtasks to smaller models, which matter for cost. The harder question is ownership. A routine without a clear owner will eventually do the wrong thing with nobody responsible for noticing.

Three of these places build on each other directly. The check written down at the turn-based level is what the goal-based loop evaluates, and the criterion defined at the goal-based level is what the proactive routine applies to each item on the stream. The trigger sits beside this chain rather than inside it: a schedule or an event source decides when the runs happen, not whether their results can be trusted. A proactive routine built on unverified goals does not automate anything useful. It repeats whatever was already broken, at a cost that grows with how often it runs.

So the loops are the visible layer, and the durable artifacts sit underneath them: the skill file, the exit criterion, the trigger, and the observability around the routine. A team can locate its missing artifact by looking at what it still does by hand. If UI changes are verified manually at the end of every session, the skill file has not been written. Case-by-case judgement on whether a fix is done usually means there is no measurable exit criterion. A script that someone remembers to start every morning is a schedule that has not been written down, and after that an event trigger. Hand triage of a steady stream of reports is a routine that has not been built yet. These artifacts outlive the specific prompt, the specific model, and the specific team. Writing them down is the work the loops post points to.
