---
layout: post
title: What UNO Teaches About Rule-Based Agents
date: 2026-08-04
categories:
- AI
- Computer Science
tags:
- ai
- computer-science
- knowledge-representation
- games
- opinion
comments: true
description: A small UNO-playing production system shows both the usefulness and the limits of rule-based agents.
---

UNO is a good toy problem for thinking about rule-based agents because the rules are simple, but the decisions are not completely trivial.

This post is adapted from an old coursework exercise of mine, but the version here is rewritten as a general design note. I am deliberately not reproducing the original prompt, diagram, or full submitted rule table.

At the surface level, the agent only needs to choose a legal card. It can match color, match value, play a wild card, draw cards, skip turns, and remember to say "UNO" before its last card. That is enough to build a production system: a set of `if` conditions connected to actions.

For example:

- If the discard card is a skip or reverse card, skip the turn when required.
- If the agent has a card matching the current color, play it.
- If the agent has no color match but has a card with the same value, play that.
- If no ordinary card is playable, consider a wild card.
- If a wild card is played, choose the color that gives the agent the strongest remaining hand.
- If no legal play exists, draw.

This kind of agent is easy to understand because its behavior is explicit. You can inspect the rules and explain why a move was made.

That explainability is the main strength of a production system.

## A sample play-through

Here is a small example of how such an agent behaves.

Suppose the visible discard card is yellow `8`, and the agent's hand contains red numbered cards, two blue `8` cards, a blue `3`, a green draw-two card, and a wild draw-four card. The agent cannot match yellow, but it can match the value. So it plays a blue `8`. This is a legal move, but it is not necessarily strategic. It simply follows the first useful rule that applies.

Now suppose the next visible card is a blue skip. If the skip was not produced by the agent's own previous move, the agent loses the turn and records that the skip effect has been consumed. That small bit of state matters. Without it, the agent might keep reacting to the same skip card as if it were a new event.

If the discard later becomes blue `6`, the agent prefers a blue card from its hand. If a wild card sets the color to red, the agent switches to a red card. If the visible card is red `5` and the hand still contains red `9`, green draw-two, and wild draw-four, it plays the red `9`.

Near the end of the hand, the agent may have only the green draw-two and wild draw-four left. If the discard is red `9`, it has no color match, no value match, and no ordinary wild card. So it plays wild draw-four, chooses the color that best matches its remaining hand, and says "UNO" because it is down to one card. If the chosen color is green, the final green draw-two becomes playable on the next turn.

The example is intentionally modest. The agent is not planning several turns ahead. It is not trying to infer the opponent's hand. It is only moving through a priority order:

- match color if possible
- otherwise match value
- otherwise use a wild option
- choose the next color based on the remaining hand
- maintain enough state to avoid misreading skip and draw effects

That is enough to play a legal sequence. It is not enough to be a strong player.

## The rule engine is not the strategy

But a legal move is not always a good move.

A simple UNO production system can play the game, but it does not necessarily play to win. It can follow the rules while still making weak choices. It may play a special card too early, hold the wrong color too long, or fail to account for an opponent's likely hand.

That distinction matters. A rule-based agent can be competent at legality without being competent at strategy.

To become stronger, the agent needs more than local rules. It needs memory and search:

- Store the agent's own previous moves.
- Track the opponent's visible moves.
- Remember which colors and values have appeared.
- Estimate what cards the opponent might still hold.
- Search across possible future states.
- Compare legal moves by expected advantage, not only immediate playability.

Once those capabilities are added, the agent changes character. It is no longer merely asking "what can I play?" It begins asking "what should I play, given what might happen next?"

## Why this still matters

This small example maps cleanly to larger AI systems.

Many production systems in business software are really rule-based agents. They approve, reject, route, escalate, notify, retry, block, or transform based on explicit conditions. That design is often the right one. It is inspectable, debuggable, and easy to constrain.

The danger comes when people mistake a rule system for a learning system, or a legal action for an intelligent action.

An agent can follow every rule and still be brittle. It can be fully explainable and still make shallow choices, performing well in ordinary cases and failing whenever the situation requires long-term planning.

That is not a criticism of rule-based systems. It is a reminder to use them honestly.

## The practical lesson

A production system is a good first agent when the domain has clear rules and a small action space. It gives you predictable behavior and a concrete explanation for each action.

But the moment success depends on strategy, hidden information, opponent modeling, or learning from history, rules alone are not enough.

UNO makes that limitation easy to see. Playing a legal card only takes rules. Playing well takes knowledge, memory, and search.
