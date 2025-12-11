---
layout: post
title: CAP Theorem
date: 2020-05-23
type: post
published: true
comments: true
status: publish
categories:
- Technology
- Computer Science
description: CAP Theorem essentially only mandates CP and AP as out of C, A and P, we always need to account for P. What are these C, A and P?
tags:
- technology
- computer-science
---
Fifteen years ago, when I started working as a Software Engineer, scalability normally meant fine tuning the application, specially the database. The other option was to increase the configuration of existing hardware, i.e., scale-up (vertical scaling).  However, these days, people prefer to scale out (horizontal scaling; as the commodity hardware becomes cheap, this has become the go to strategy) - add more hardware to fulfil the request with reasonable response time. Scale out seems easy to architect, but is profoundly complex. And to increase the complexity, the CAP Theorem comes into picture. 

According to CAP Theorem[^fn1], "it is impossible for a distributed data store to simultaneously provide more than two out of the following three guarantees:

 * Consistency (C) - Every read is guaranteed to receive the most recent write
 * Avaialbility (A) - Every request receives the response in a timely manner
 * Partition Tolerance (P)  - The system continues to operate even though messages (or data packets) might be dropped by the network nodes (i.e., network partition occurs)
 
 So, as per CAP theorem, either CA, CP or AP are possible. However, networks are not reliable so we must always account for Partition Tolerance, that rules out CA. Thus, we have only two options CP or AP and we must decide between the two:
 
 * CP (Consistency and Parition Tolerance) - Basically, it means  reject the request and thus decrease the avaialbility but ensure only consistent response are sent to the client. If your system needs atomic transactions (read or write), this is what you must desire to achieve. This is mostly true for synchronous systems, i.e., systems that perform operations as soon as the request arrives. 
 
 
 * AP (Availability and Partition Tolerance) - Respond to the request even with an inconsistent or stale state. This ensures availability but reduces consistency. This also means that you can respond asynchronously to the write transactions. You can accept the write request, perform operations later and response when the network partition has been resolved. 
 
 
 [^fn1]: [https://en.wikipedia.org/wiki/CAP_theorem](https://en.wikipedia.org/wiki/CAP_theorem)
