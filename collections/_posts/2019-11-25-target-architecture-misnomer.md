---
layout: post
title: What is Target Architecture?
date: 2019-11-25
type: post
published: true
comments: true
status: publish
categories:
- Technology
tags:
- design
- domaindrivendesign
- softwarearchitectue
- targetarchitecture
description: One phrase true for Target Architecture - Never Achieved.
featured: true
---

“I want to be in Target Architecture”, a high stake person in a company said. The problem is that no body understands what is Target Architecture. The phrase is so convoluted and confusing that it is not easy to define it, rest alone achieve it. Technology is always evolving. If it is evolving, then your architecture should be evolving as well. If our architecture is evolving, then there cannot be a finite target architecture. We can only have Target States of Architecture - one which help you set the goal and vision for the current set of projects to prevent them go rogue. But you will keep moving from one Target State to another. 

From Domain Driven Design perspective, you can define Target Domains, as once we have identified domains for wer company/department/line of business, it is highly unlikely they will change frequently. They may also evolve as wer understanding of problem domain expands, but mostly they should remain stable at a high-level.  

Let’s stop pretending that we know what Target Architecture is, and we are ever going to achieve it.

I agree to the point that lifecycle of an application in an enterprise (financial or otherwise) is three years including development and decommission, which themselves might take 6 months each and that is why we need to come up with an architecture, which solves wer business needs for next three years. We work on design and development following an architecture which provides us with the capability to jump in future. But saying that this architecture is Target Architecture is misnomer. At best we are defining it only for few years. If we are then we are always evolving. If we tie down to the architecture and call it Target Architecture, it gives we less freedom to move away when we discover that no, it not really is where we want to be.

Some will argue that continuously evolving architecture is a myth spread by people who do not understand application architecture. Architectural changes are always disruptive and radical (otherwise they won’t be called as architectural changes). Allowing application to scale functionally (by supporting more features) or non-functionally (eg by making application more and more fault tolerant or making application process more load) has to be an organic process. It needs to be thought in advance and even though not implemented, the hooks for additional scaling must be present in the application. To this I will argue that evolutionary architecture is not a myth. 10 years ago, the application we wrote, was no longer in the same state three years later. If it was designed with a thought that business might change or technology might change, the architecture should give us the pipe and hooks to emerge out of it. If not, then whatever will be left will be just a mess - one that no one wants to own and no one wants to clean. That means we are talking in terms of semantic differences. Due to the rapidly evolving technologies, the application lifecycle is very short now, but it is still not feasible to rearchitect an application every now and then to take the benefits of new technologies/frameworks. But within this short span what can evolve are the design or the delivery processes if the application is architected thoughtfully. 
What typically happens is that some organizations lag behind for some time compared to their competition, but once they decide to rewrite the applications they can leapfrog and go to even better architecture and become leaders. Organization needs to make sure that it is not holding on to the older applications beyond the lifecycle of the technologies even though those applications have not recovered their cost of development. The opportunity cost should always be considered.

There is a term called Emergent Architecture, which is better than Evolutionary Architecture. As far as my understanding goes, the target states are the building blocks toward the next state - evolving and emerging into new block and the chain continues. We do minimal upfront design and architecture discussion, only necessary for current project (or group of projects) and use the state thus reached to emerge (evolve) into a new state. 

I have observed that we are trying to design the overall architecture upfront and by the time we finish and make decisions, the project is either scrapped because we didn't start delivering value or the assumptions that we made about the architecture and design decisions that we made are no longer valid. 

Thus we need some agility (real sense Agile development, not in the form that we do it in enterprises these days). We need architecture, but like salt, it should be right amount and added at right time. 