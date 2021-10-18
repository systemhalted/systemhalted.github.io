---
layout: post
title: (Draft) State, Immutability and Microservices
category: [Insane Thoughts, Technology, Software Engineering]
tags: [state, immutability, microservices]
comments: true
description: Through this post trying to make sense of microservices
---

The state of a system is a description that is sufficient to determine the future. 

In case of an immutable System, the above statement will hold. However, in case of a mutable system, it will not. This is because the state of such a system can change in between. 

The Microservices is a way to limit the mutability of a system. You provide the bounded context and make sure the system can be mutated by itself. No other system should be mutating this system. That is one of the advantages of a Microservice. 

(To be finished)