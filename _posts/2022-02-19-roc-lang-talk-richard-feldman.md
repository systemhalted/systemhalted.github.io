---
layout: post
title: Roc Lang and Compiler Optimization by Richard Feldman
category: [ Programming, Computer Science, Compilers]
tags: [roc-lang, compilers, functional programming, elm, richard_feldman, haskell, compilers, optimizations, llvm]
comments: true
description: Loved this talk by Richard Feldman on Roc-lang in particular and language optimization in general.
featured: true
---

Recently,  I listened to the talk "Outperforming Imperative with Pure Functional Languages"[^1] by Richard Feldman [^2] on Roc Lang's performance [^3]. I loved the talk. I have listened to several talks on new languages and language design but this talk stands out because it was not a talk that bashed other languages but articulated the need for a new language (albeit briefly) and how functional programs can be made to be performant in comparison to the imperative languages like Java, C++, etc. 

This is really a great talk. The talk covered three main performance considerations:  
1. Language Overheads 
2. No side effects
3. No mutation.

#### Language Overheads

For Language Overhead, Richard mentions that Roc is LLVM compiled to binary, differentiating from compiled to binary. Though Richard does not mention why LLVM compiled to binary gives a performance bump, I will try to give my opinion on it[^4]. 

LLVM has three major components - Frontend, Optimizer, and Backend. Source code is fed into LLVM Frontend (in case of C++, CLang), which parses the source code checking it for errors, and builds a language-specific Abstract Syntax Tree (AST) to represent the input code [^5]. The optimizer is responsible for variety of transformations, to try to improve the code's running time. This is done by parsing and converting the code into LLVM's Code Representation, known as LLVM Intermediate Representation (IR), which is a low-level RISC-like virtual instruction set. This IR is what optimizer uses for, you guessed it right, optimization. This IR makes optimizer independent of the source language and the target machine. The backend (or code generator) maps the IR onto the target instruction set. 

In my view, LLVM IR is the main reason that many optimizations are possible. The other advantage is that if you use LLVM for language C++ or Rust, you can reuse the optimizer (and backend, if you are targetting same machines) for a new language like Roc, only thing that you have to worry about is the creation of new Frontend to convert the Roc source code into the LLVM IR. I am not sure that is what Roc and Richard have in mind. Probably, need to listen his more talks on the topic, if he has any [^3].

In his talk, the second point he makes is of using static refcounting and mentions two papers [^8][^9]. I have no idea what that is, will need to read those papers and probably write something later. 

The other thing he mentions in his talk is use of Unboxed values. It is interesting way of memory management. In Haskell, you can have boxed values, like Int, which is a two-word heap object. In the case of boxed values, you need to allocate the value on heap and then refer to it using pointers/references. The unboxed value is represented by the value itself without need of any pointers. Since you are avoiding the overhead of heap allocation and pointers, you are going to get a speedup. 

#### No Side Effects

Richard talks about how Haskell and Roc use Managed Effects. What I understand is that in these languages the entire chain of side effects is first created and not executed at time of instantiation but only after the complete chain has been created. I think kind of lazy evaluation[^10]. This is surely an overhead as you need to manage each side effect. The Roc is achieving this by keeping the Tasks and Closures as Unboxed and instead of using function pointers for function calls, using enumerated direct calls. Again, I am no expert. 

#### No Mutation

Any imperative loop (while, for, etc.) can be expressed as a recursive function. Tail call optimization makes them compile to the same thing. Same idea is taken for any program that needs in place mutation through Opportunistic In-Place Mutation. This optimization can be done by using Reference counting instead of tracing Garbage Collector(GC) and this in most cases this can be done using Static In-place Detection, so this can be done at Compile time rather than runtime. It uses Alias Analysis via Morphic Solver library written in Rust created at University of California, Berkeley. I couldn't find much information on that. Probably this will come later as well. 

#### Conclusion
This talk was fantastic. I would recommend go and listen to the talk. I have been thinking of writing about LLVM for past two years. Now, probably, I will concentrate more on writing about LLVM.  

*References*  

[^1]: https://www.roc-lang.org/
[^2]: https://www.youtube.com/watch?v=vzfy4EKwG_Y  
[^3]: https://www.linkedin.com/in/rtfeldman/  
[^4]: (I call it opinion because I am no expert. Only work that I have done on LLVM was in CS6340[^6] course at GATech OMSCS[^7])  
[^5]: https://omscs.gatech.edu/home  
[^6]: [CS6340 - Software Analysis and Test](https://omscs.gatech.edu/cs-6340-software-analysis) is one of the best courses offered in OMSCS. If you are planning to take one course in OMSCS, try this one. Thoroughly enjoyed this course.   
[^7]: http://www.aosabook.org/en/llvm.html  
[^8]: https://www.microsoft.com/en-us/research/uploads/prod/2020/11/perceus-tr-v1.pdf
[^9]: https://arxiv.org/pdf/1908.05647.pdf
[^10]: https://wiki.haskell.org/Lazy_evaluation