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
---

Last year I have worked a lot on Distributed Runtime environments specially using Spring XD. Spring XD provides a way to create Streams which can process lot of flowing data in real time. Spring XD internally uses Spring Integration for most of the processing of data. However, it is impossible for any module to handle lots of data in real time. This is handled through defining protocols for message transfer which is nothing but a Queue. This queueing mechanism enables the creation of real-time streams. 

In a programming language like Haskell, functional reactive programming is implemented using the Lazy evaluation as well. You can declare a reactive data, say _b = (a+2)_. Now value of _a_ is unknown till specified but _b_ is defined and doesn't throw any error and can be evaluated when the value of a is specified a little later. This happens due to what Haskell supports under the hood - Lazy Evaluation. 

Now compare that to Reactive programming. Though they are not at same level but reactive programming is possible due to lazy data structures. 

In the world of Spring XD, the queue enables the Lazy evaluation. This allows an infinite existence of data that can be evaluated. 
The other way to implement would have been to loop through all the data but again that would have been cumbersome and ugly. 

Spring XD is nothing but the implementation of Reactive Architecture where the different modules are talking to each other through events published to them. So, all in all everything is working due to Lazy evaluation within the hoods. 

**Disclaimer:** _This post may not be entirely true technically. These are just my thoughts and understanding of few things that I am currently working on to make more sense of the work that I do._ 

