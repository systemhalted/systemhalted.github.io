---
layout: post
title:  Project Jigsaw - Part 1 - What is Modularity?
date: 2016-08-31
type: post
published: false
comments: true
status: draft
categories:
- Technology
- Programming
tags:
- jdk9
- java
- modular-java
- modular java
- project-jigsaw
- project jigsaw
- jigsaw
description: What is Project Jigsaw?
---

  For past few years we have seen quite a change in the world of Java. JVM and JDK both are changing and changing for good. JDK 8 entirely changed the Java landscape with inclusion of support for lambda and providing a way to be a little more functional. A similar role will be played in JDK 9 by Project Jigsaw, also known as JSR376, the project that will enable modularity in Java
   
  Many people would argue that Java already supports modularity - jars are the modules and so are the wars and ears. From source code perspective, it supports packages and encapsulation. So, why Project Jigsaw?
  
  ** What is a module? **
  
  Before, I answer Why Project Jigsaw, let us define modularity and identify some characteristics that a module must have to be identified as a module. 
  
  The very basic definition of Modules would be the group of related code. The code that focuses on a specific area of concern. For example, java.util.concurrent package is a module in its own with focus on Concurrency (as the name also suggests). Similarly, java.lang can be considered another module and java.util another. 
  Let us examine what is common in these packages that we can consider them as modules:
  
  1. The first and foremost is encapsulation. Java supports encapsulation by use of access modifiers and packages. Encapsulation helps in hiding the code that we don't want to expose publicly. In POJOs world, we declare class variables as private and provide getters and setters, as required, to control the behavior of an object. This helps us in preventing any accidental changes. 
  
  2. To make a module talk with other modules, however, you cannot have everything encapsulated. This leads us to our second characteristic - Public API or Interfaces. The API is the part of the code that is available publicly. One modules can use the public interfaces of another module to interact with it. Importantly, this is the only way to communicate between modules. 
   
  The above are the two of the important characteristics that a module must have. 
  
  Let us explore further. We discussed modularity in terms of encapsulation and packages in JDK. We have other modules like jars. 
  Now jars can be dependent on other jars as well. For example, 
  
   
   
   
  