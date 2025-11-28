---
layout: post
title: Lazy Evaluation, Streams, Reactive Programming and Reactive architecture
date: 2016-09-19  23:07:00.000000000 -6
type: post
published: true
comments: true
status: publish
categories:
- Technology
- Programming
tags:
- lazy evaluation
- streams
- reactive programming
- reactive architecture
- haskell
- spring xd
description: An attempt to make sense of the world I work in. 
---
Last year I spent a lot of time working with distributed runtime environments, especially using Spring XD. Spring XD gives you a way to define streams that process continuous flows of data in near real time. Under the covers it builds on Spring Integration and messaging. No single module can keep up with every burst of traffic on its own, so Spring XD relies on messaging middleware such as queues and topics. These queues decouple producers and consumers and buffer data so that the system as a whole can keep up, even when individual modules have limited capacity.

In Haskell you see a different but related idea in the form of lazy evaluation. For example, you can write a simple definition like b = a + 2. Even if a is not known yet, the definition of b is valid. Haskell does not compute b until some later point when its value is actually needed and a has been provided. This is the essence of laziness in the language. Functional reactive programming libraries in Haskell build on this style of thinking, representing time varying values and streams as ordinary values that are only evaluated when required.

Reactive programming in general is not the same thing as lazy evaluation, and it does not depend on lazy data structures. You can build reactive systems in strict languages like Java, Kotlin or C Sharp. The common thread is the idea of data streams and propagation of change. You compose operations over streams of events and let the runtime push values through that pipeline as they arrive, often with some form of back pressure to avoid overwhelming consumers.

This is where the analogy with Spring XD comes in. In Spring XD the queues between modules let you treat incoming data as an unbounded stream that can be processed at the pace of the consumers. Producers publish messages as they arrive, queues hold those messages, and consumers pull and process them as they are ready. You never loop over a fixed collection of all possible data. Instead you react to data as it flows through the system over time.

So Haskell laziness and reactive architectures like those built with Spring XD solve similar problems from different directions. Laziness delays computation until a value is demanded. Reactive architectures delay work until an event arrives and a downstream component is ready. The mechanisms are different, but the shared idea is powerful: do work only when there is a consumer that actually needs the result.

