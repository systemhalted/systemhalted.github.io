---
layout: post
title: C Strings - Awkward By Design
date: 2019-12-26
type: post
published: true
comments: true
status: publish
categories:
- Software Engineering
- Computer Science
tags:
- software
- computer-science
description: C is a funny language. Strings are a joke.
featured: true
---
C is a funny language. It was designed for performance and still prides itself on being close to the metal. Yet the way it deals with strings is, let us say, special. To be more precise, spectacularly awkward. In C, strings are not really citizens at all. They are just a convention.

There is a famous joke on C strings, which I reproduce here

```Two strings walk into a bar. The bartender says, "What'll it be?".
   The first string says, "I'll have a vodka with cranberry 
   juice#MV*()>SDk+!^&@P&]JEA&#65535;Segmentation Fault".
   The second string says, "You'll have to excuse my friend, he's not null-terminated."
```


String Declarations in C
=========================

Suppose you have this declaration:

{% highlight c %}
char *str = "palak";
{% endhighlight %}

There are a few important things hidden in that single line.

First, this is not creating a mutable character buffer. It is creating a pointer to a string literal, which is typically stored in read only memory. Writing to `str[0]` is undefined behaviour.

If you want an actual character array you can change, you should write:

{% highlight c %}
char str[] = "palak";
/* or equivalently */
char str[] = { 'p', 'a', 'l', 'a', 'k', '\0' };
{% endhighlight %}

Notice the extra '\0' at the end. That is the null character that terminates the string. So the array needs six bytes, not five.

Buffers and the Null Terminator
================================

This leads to a classic pitfall. If you declare a buffer of size `BUFFER_SIZE` and then read exactly `BUFFER_SIZE` bytes of input into it, there is no room left for the terminating `'\0'`. At that point functions that expect null termination will happily walk past the end of the buffer.

The usual pattern is simple. You declare a buffer of size `BUFFER_SIZE`. You read at most `BUFFER_SIZE - 1` characters into it. Then you add the null terminator yourself or rely on a function that guarantees it, such as `fgets`.

For example:

{% highlight c %}
char buf[BUFFER_SIZE];
fgets(buf, BUFFER_SIZE, stdin);  /* leaves room for '\0' */
{% endhighlight %}

How strlen Works?
==================

In C, the length of a string is given by `strlen()`.

In many higher level languages such as Java, a string is stored as a counted or length prefixed sequence. The length is computed once when the string is created and stored alongside the character data. Asking for the length is then effectively constant time.

C takes a different path. `strlen()` works by starting at the first character and walking forward in memory until it finds the null character `'\0'`. That means the time complexity of `strlen()` is not `O(1)`, it is `O(n)` in the length of the string.

At first sight that looks like an anti pattern. Why not just store the length and be done with it?

Historical Tradeoffs
====================

Here is where history and tradeoffs enter.

C does not have a built in string type. A “string” in C is simply a sequence of character codes in consecutive memory, followed by a null character. Those codes can be ASCII, EBCDIC, or something else entirely.

When Unix and early C code were written, memory was extremely limited and there was no virtual memory. The operating system kernel, applications, and their data all had to fit into a very small space.

In that environment, storing an extra length field for every string was seen as wasteful. The null terminator convention won because it was compact and simple, even though it made some operations, like computing the length, inherently linear in time.

Other systems made different choices. For example, Pascal style strings are length prefixed, and you can still see traces of that heritage in some older Mac and Windows APIs.

Compactness versus Convenience
==============================

So C’s null terminated strings are a compromise. They favor compact representation and simple layout in memory over constant time length checks and some kinds of safety.

Efficiency is not only about speed. It is also about space and simplicity of the generated code. In the environments where C first thrived, those tradeoffs made sense.

Later, C++ introduced std::basic_string and its aliases like std::string to provide a higher level abstraction that typically stores the length and hides the implementation details.

Are C Strings an Anti Pattern?
===============================

From today’s point of view, especially if you live in languages with safe, immutable, length tracked strings, C’s approach can look like a bug disguised as a feature.

From the point of view of 1970s Unix on tiny machines, it was a pragmatic design that kept the system small and fast enough to exist at all.

In other words, C strings are both an anti pattern and not an anti pattern. It depends which decade you are standing in and which costs you care about more: simplicity and space, or safety and constant time convenience.
