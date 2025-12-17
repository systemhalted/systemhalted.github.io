---
layout: post
title: "Escaping GOTO: How We Learned to Make Programs Readable"
date: 2025-12-17
published: true
comments: true
categories: 
  - Technology, 
  - Computer Science
  - Series 2 - Turtle, BASIC, and the Long Road to Taste
tags: [basic, gw-basic, goto, structured-programming, programming, software-engineering]
description: Line numbers made BASIC feel orderly. GOTO made it powerful. Then everything turned into spaghetti.
---

In early BASIC, the line numbers felt like street addresses.

You could point to a place in your program and say: "Go there."
The computer would nod, politely, and do exactly that.

And for a beginner, this felt comforting. Orderly. Almost architectural.

{% highlight basic %}
10 PRINT "Hello"
20 PRINT "World"
30 END
{% endhighlight %}

A neat little staircase of intentions.

Then we learned the spell.

## The seduction of GOTO

GOTO is the programming equivalent of discovering you can teleport.

Why walk like a peasant when you can jump?

Want a loop? Jump back.

{% highlight basic %}
10 LET X = 0
20 LET X = X + 1
30 PRINT X
40 IF X < 5 THEN GOTO 20
50 END
{% endhighlight %}

It works. It’s simple. It even feels clever.

But teleportation has a cost: once you start jumping, your program stops being a story and becomes a maze.

## The day BASIC stopped feeling friendly

At some point the program gets longer than your short-term memory.

You add one more rule. Then another.

Now you’re jumping forward to handle special cases, jumping back to repeat, jumping sideways to "retry," and suddenly you’re not writing code.

You’re playing detective.

Here’s the kind of shape that starts to appear:

{% highlight basic %}
10 INPUT "Enter a number (1-10)"; N
20 IF N < 1 THEN GOTO 90
30 IF N > 10 THEN GOTO 90
40 PRINT "OK"
50 GOTO 110
90 PRINT "Invalid. Try again."
100 GOTO 10
110 END
{% endhighlight %}

This is still readable.

But scale it up a bit: ten validations, multiple modes, nested loops, an error path, a "back" option, and suddenly the logic is scattered across line numbers like breadcrumbs thrown into a hurricane.

You don’t read it anymore.
You trace it.

Tracing burns attention. Attention is expensive.

That’s the real crime of spaghetti code: not aesthetics, cognitive cost.

## Why it turns into spaghetti

A clean program has a shape you can hold in your head:

Start → do things → finish.

Unstructured jumps destroy that shape.

GOTO breaks the one promise your reader desperately wants: that control flow will be local and predictable.

If any line can jump to any other line, then every line must be read with paranoia.

That’s not programming. That’s anxiety with line numbers.

## The escape: structured programming

Structured programming wasn’t invented to be fancy.
It was invented to make code readable at scale.

Instead of "jump anywhere," you get a small set of composable structures:  
	•	sequence (do this, then that)   
	•	selection (if/else)   
	•	iteration (for/while)   

You still do the same things, but the control flow becomes visible again.

Here’s the key move: instead of scattering retry logic across labels, you put it inside a loop.

If your BASIC dialect supports WHILE...WEND (many did), you can do:

{% highlight basic %}
10 PRINT "Enter a number (1-10)"
20 INPUT N
30 WHILE N < 1 OR N > 10
40   PRINT "Invalid. Try again."
50   INPUT N
60 WEND
70 PRINT "OK"
80 END
{% endhighlight %}

Now the program reads like a story again:

Ask → repeat until valid → proceed.

Same behavior. Different shape.

And that shape is the whole point.

## The lesson: don’t use GOTO

Here’s the grown-up version, stated plainly:

Don’t use GOTO.

Yes, there are rare cases where it can be used carefully: generated code, constrained environments, or very low-level cleanup paths.

But that’s not the world most of us are programming in.

In real software, with real teammates and real deadlines, GOTO is a trap. It makes control flow non-local, and non-local flow makes reasoning expensive. It turns debugging into archaeology.

So the beginner-to-professional upgrade is simple:

Stop jumping. Start structuring.

If you need to repeat, use a loop.
If you need to choose, use IF...THEN...ELSE.
If you need to reuse, use a function.
If you need to abort, return early or throw an error.

Your future self will thank you. Your teammates will thank you. Your pager will thank you.


## Final Thoughts

Logo taught me wonder: move the turtle, watch a picture appear.

BASIC taught me discipline: tell the machine exactly what to do, step by step.

But the most important thing BASIC taught me might be this:

A program is not just instructions for a computer.

It is a story for the next human.

And the moment your story needs a map and a compass, you’ve stopped writing a program and started writing a trap.