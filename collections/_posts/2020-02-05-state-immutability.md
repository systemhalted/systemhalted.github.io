---
layout: post
title: State, Immutability and Microservices
category:
- Software Engineering
- Computer Science
comments: true
description: Through this post trying to make sense of microservices
tags:
- software
- computer-science
---
The state of a system is the information you need at a given moment, together with its rules of behaviour, to predict how it will evolve in the future. At time T the system has some state, it receives inputs, applies its rules, and moves to a new state at time T plus one.

In an immutable style, values do not change once they are created. Instead of updating an object in place, you produce a new version that represents the next state. This makes state easier to reason about, because you know that once a value exists it will never be silently changed by some other part of the program.

In large distributed systems the real problem is not mutability itself, but shared mutability. When many components can change the same data directly, the future behaviour of the system becomes hard to predict. Any part of the system can affect that shared state at almost any time.

Microservices address this by putting strong boundaries around state. Each service owns a specific bounded context and the data that belongs to it. Only that service is allowed to change its data, and all changes go through its public API or through events it publishes. Other services cannot bypass these boundaries to mutate its data store directly.

This does not remove mutability, but it confines it. State is still changing over time, but it changes in well defined places, under well defined rules. That is one of the key benefits of a microservice architecture: clearer ownership of state and fewer surprises about who is allowed to change what.

You can build nicely on top of this by adding event sourcing, immutable logs, or snapshots, but the core idea stays the same: keep mutations local, keep boundaries clear, and let each service be the single source of truth for its own state.
