---
layout: post
title: Clojure and Polish Notation 
category: [Personal, Cycling] 
tags: [Cycling, Diamondback Hybrid Bike, Dicks Sporting Goods]
comments: true
summary: Clojure syntax is prefix notation and it is difficult to switch to using it. 
--- 

Clojure is a functional programming language targeting JVM developed by Rich Hickey. It is a dialect of Lisp, which is 
distinctive with the use of parenthesis and [Polish notation](http://c2.com/cgi/wiki?PolishNotation) (generally referred
to as Prefix notation). Clojure follows the same fully-parenthesized Polish prefix notation. 

It is a beautiful language. However, people get scared when they see the prefix notation and lot of parenthesis. For example,

``` clj
(+ 3 4 (+ 3 3 5)
```  

Recently, a question was asked on [Java Ranch](http://www.coderanch.com/t/661955/clojure/Clojure-Action) and I tried to 
answer the question to the best of my knowledge. I am just presenting it here. 

I can understand that being taught to use infix notation throughout the school and then in most of the other programming 
languages of choice, it is difficult to switch to prefix mode, which is also known as Polish notation. Having said that
it is easier to understand and grasp but needs a good amount of patience to reach that level. 

The syntax may come handy if you think about tree-structured data. The expression, say ```(* A B) ```, which is equivalent to 
```A * B``` in infix, is represented as 

        *
      /   \
     A     B

So, the Polish prefix notation is just a way to represent the s-expression in a tree data structure in one line, * comes
first followed by A and then B, equals, ```* A B``` and in Lisp world of parenthesis ```(* A B) ```

This complication is mostly for mathematical functions like +, -, * and /. However, other functions are very easy. For
 example, a call in Python like programming language would look like, 
 
``` python
print "Hello World!"
```

This is nothing but a prefix notation and can be represented in Clojure as

``` clj
(print "Hello Word!")
```

I  have never developed a full-scale application in Clojure or LISP, but I find it much easier to understand the code in 
Clojure then Java. It is easier to make Java code look horrible, it is equally difficult to do so in Clojure. 

I find this article named [The Nature of Lisp](http://www.defmacro.org/ramblings/lisp.html) on the steep curve in learning 
Lisp worth reading. And also, [2 MYTHS AND 2 FACTS ABOUT CLOJURE THAT CHANGE EVERYTHING](http://blog.cognitect.com/blog/2015/9/21/2-myths-and-2-facts-about-clojure-that-change-everything)

Some links shared on the same post in Java Ranch by Peer Reynders are:

Talks:  
[(Neal's) Master Plan for Clojure Enterprise Mindshare Domination - Neal Ford](https://www.youtube.com/watch?v=2WLgzCkhN2g&feature=youtu.be&t=1619)
[Simple Made Easy by Rich Hickey](http://www.infoq.com/presentations/Simple-Made-Easy)  
[Sneaking Clojure Past the Boss](http://www.coderanch.com/t/586641/clojure/Sneaking-Clojure-Boss)  
[Selling Clojure to Business](https://blog.juxt.pro/posts/selling-clojure.html)  
[PolyConf 15: Contracts as Types / Jessica Kerr](https://www.youtube.com/watch?v=zLyd_Ey1GPM)   