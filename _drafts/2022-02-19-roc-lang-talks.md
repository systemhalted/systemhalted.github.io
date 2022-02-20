---
layout: post
title: Roc Lang by Richard Feldman
category: [ Programming, Computer Science]
tags: [roc-lang, compilers, functional programming, elm, person:richard_feldman]
comments: true
description: Loved few of the talks by Richard Feldman on Roc-lang in particular and language design in general
---

Recently,  I listened to the talk "Outperforming Imperative with Pure Functional Languages"[^1] by Richard Feldman [^2]. I loved the talk. I have listened to several talks on new languages and language design but this talk stands out because it was not a talk that bashed other languages but articulated the need for a new language (albeit briefly) and how functional programs can be made to be performant in comparison to the imperative languages like Java, C++, etc. 

This is really a great talk. The talk covered three main performance considerations:  
1. Language Overhead 
2. No side effects
3. No mutation.

1. For Language Overhead, Richard mentions that Roc is LLVM compiled to binary, differentiating from compiled to binary. Though Richard does not mention why LLVM compiled to binary gives a performance bump, I will try to give my opinion on it. (I call it opinion because I am no expert. Only work that I have done on LLVM was in CS6340[^3] course at GATech OMSCS[^4]). 

LLVM has three major components - Frontend, Optimizer, and Backend. Source code is fed into LLVM Frontend (in case of C++, CLang), which parses the source code checking it for errors, and builds a language-specific Abstract Syntax Tree (AST) to represent the input code [^5]. The optimizer is responsible for variety of transformations, to try to improve the code's running time. This is done by parsing and converting the code into LLVM's Code Representation, known as LLVM Intermediate Representation (IR), which is a low-level RISC-like virtual instruction set. This IR is what optimizer uses for, you guessed it right, optimization. This IR makes optimizer independent of the source language and the target machine. The backend (or code generator) maps the IR onto the target instruction set. 

In my view, LLVM IR is the main reason that many optimizations are possible. The other advantage is that if you use LLVM for language C++ or Rust, you can reuse the optimizer (and backend, if you are targetting same machines) for a new language like Roc, only thing that you have to worry about is the creation of new Frontend to convert the Roc source code into the LLVM IR. 

2. 






*References*
[^1]: https://www.youtube.com/watch?v=vzfy4EKwG_Y
[^2]: https://www.linkedin.com/in/rtfeldman/
[^3]: [CS6340 - Software Analysis and Test](https://omscs.gatech.edu/cs-6340-software-analysis) is one of the best courses offered in OMSCS. If you are planning to take one course in OMSCS, try this one. Thoroughly enjoyed this course. 
[^4]: https://omscs.gatech.edu/home
[^5]: http://www.aosabook.org/en/llvm.html