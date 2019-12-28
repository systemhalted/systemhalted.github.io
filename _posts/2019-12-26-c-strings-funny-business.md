---
layout: post
title: C Language - Strings and the Funny Business
date: 2019-12-26 
type: post
published: true
comments: true
status: publish
categories:
- Programming
tags:
- C
- Strings
- strlen
- Null-pointer
- anti-pattern
- technology

---

C is a funny language. It is made for performance and prides itself to be performant. However, when it comes to strings and how C deals with them is extraordinary. To be precise, extraordinarily deplorable. C treats strings as third class citizens.

There is a famous joke on C strings, which I reproduce here

```Two strings walk into a bar. The bartender says, "What'll it be?". The first string says, "I'll have a vodka with cranberry juice#MV*()>SDk+!^ &@P&]JEA&#65535;Segmentation Fault". The second string says, "You'll have to excuse my friend, he's not null-terminated."```

Now let us delve further.  Suppose you have the following string:

```char *str = "palak";```

There are few things that are very important to understand:

1. This is same as 
 ```char *str = {'p','a','l','a','k','\0'};```

2. If you notice, the size of the store for the string is one more than the size of the string. So, if you declare your buffer of certain size and while I/O, you are reading the same size, you might be in for a huge surprise. So, if you declare your  buffer of size `BUFFER_SIZE`, read `BUFFER_SIZE - 1` of data into it.

Now, coming back to the funny business. The length of the string in C is given by function `strlen()`. In Java and other languages, the String is counted-length string, which means the length of the string is calculated once at the time of creation and stored.  However, the way `strlen()` counts the length is by moving the pointer till it encounters the Null pointer (`\0`). So, essentially it means that the time complexity for `strlen` is not O(1) but O(n). Isn't this an anti-pattern? Why would C not store the length? The answer to this was provided by one of my friend Hidemoto on LinkedIn, where this post initially appeared.

  C does not have strings as its primitive type.  Strings is a just sequence of character codes, which could be ASCII, Unicode, EBCDIC, or any other code, eventually terminated with `null`. This sequence occupies a consecutive area in the memory allocated for a particular application. When Unix was implemented with C, memory size on the system was very limited and there was no Virtual Memory.  Unix Kernel, application and their data needed to share same memory space, so string library was implemented with null termination to conserve memory.  However, some modern Operating Systems, such as Macintosh System and  Windows, used Pascal as their preferred language at very early stage and its string implementation was length-prefixed string.  You can still find the legacy of Pascal influence in their API calling convention and `B_STR` type in Windows/OLE/COM.

So, C uses null terminated string as a compromise for compactness of code. Remember efficiency is not only the speed.  Of course, the current computing environment, excessive memory and CPU, productivity and speed is more important than compactness or preciseness of application.

In fact, C++  has later abstracted string with` std::basic_string` class and it is supposed to hide internal implementation.

So, answer to the question, whether Strings in C are an anti-pattern depends on what shades you like. It is an anti-pattern and not an anti-pattern at the same time. 
