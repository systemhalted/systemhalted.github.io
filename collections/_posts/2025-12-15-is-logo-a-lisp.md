---
layout: post
title: Logo Looks Nothing Like Lisp and Yet It Is
published: true
comments: true
categories:
  - Technology
  - Computer Science
  - Series 2 - Turtle, BASIC, and the Long Road to Taste
tags: [logo, lisp, computer-science, education, turtle-graphics]
description: Why Logo can be called a Lisp dialect even though it does not look like one?
featured_image: assets/images/featured/2025-12-15-is-logo-a-lisp.png
featured_image_alt: Illustration with two computers - one with Logo code and the other with lisp - for comparison purposes
featured_image_caption: Logo Looks Nothing Like Lisp and Yet It Is
---

It was in 1991 that my school[^1] introduced Computer Science for everyone from class IV onwards. It was the first school in Agra[^2] to do so[^3]. Luckily for me I was in class IV and was excited to learn Computer Science. 

The first day of the class we were excited. We did not get to see the newly build Computer Labs but were told lots about Computers - what is a computer? what is data? what is meaningful information? cpu, alu, monitor, keyboard and the funniest of all - the mouse. Soon we progressed to learn programming and the language of choice for that was **Logo**[^4]. 

In Class IV, Logo felt like magic with training wheels.

A turtle sat at the center of the screen and waited for commands. You would say:

{% highlight logo %}
FD 50 RT 90 FD 50 RT 90 FD 50 RT 90 FD 50 HT
{% endhighlight %}

and a square would appear, as if geometry had agreed to be friendly for once.

## Logo is Lisp?

Years later, I discovered a fact that sounds like a prank until you stare at it long enough:

Logo is often described as a dialect of Lisp, or at least a Lisp-family language.[^5]

That claim is confusing at first because Logo does not look like Lisp. Lisp is famously parenthesized. Logo is famously turtle-ish. So what gives?

The trick is that "dialect" here is not about surface syntax[^6]. It is about the underlying ideas: evaluation, data structures, and the way programs are shaped.

Below are the family resemblances hiding in plain sight.

### 1. Prefix thinking: verbs first

Lisp’s signature habit is that functions come first, arguments follow.

{% highlight lisp %}
(+ 3 4)
(forward 50)
(right 90)
{% endhighlight %}

Logo does the same thing, it just drops the parentheses and speaks like a teacher.

{% highlight Logo %}
sum 3 4
fd 50
rt 90
{% endhighlight %}

Same mental model. Different costume.

### 2. Lists matter a lot

Lisp is built on lists. Logo inherits that list-centered worldview.

In many Logo dialects you can work with lists directly:

{% highlight Logo %}
print [1 2 3 4]
print first [a b c]     ; a
print butfirst [a b c]  ; [b c]
{% endhighlight %}

If you have ever met Lisp’s car and cdr, you can feel the same head-and-tail spirit here, just with names that won’t scare a fourth grader.

### 3. Quoting and symbols: "name" vs "value"

In Lisp, quoting is essential because you often want to talk about symbols without evaluating them.

Logo has a similar separation between a name and a value.

In UCBLogo-style notation:

{% highlight Logo %}
make "x 10
print :x
{% endhighlight %}

The "x is the symbol name. The :x is the value stored in that name.

Different punctuation, same conceptual split: symbol vs value, data vs evaluation.

### 4. Recursion feels natural, not exotic

Lisp culture loves recursion because it pairs naturally with lists and self-similar problems.

Logo teaches recursion early too, especially in dialects like UCBLogo.

A simple recursive spiral:

{% highlight Logo %}
to spiral :n
if :n < 1 [stop]
fd :n
rt 90
spiral :n - 1
end
{% endhighlight %}


Here we are declaring the function named spiral. `to` is the keyword to declare functions in Logo.

This is not "turtle magic." This is a core Lisp-family habit: define a procedure, then solve the big problem by repeatedly solving smaller versions of it. 

### 5. Code-as-data vibes: instruction lists you can run

One of Lisp’s deepest tricks is that code and data are made of the same stuff. That enables patterns like building code as a data structure, then evaluating it.

Logo approaches that idea in a friendlier way: lists can represent sequences of commands, and many Logo environments support executing those command lists.

Even when you never say the word "eval," you are inching toward the same philosophical cliff: programs can be treated as manipulable objects.

That is very Lisp. It is also very sneaky.

## Final Thoughts

Logo doesn’t look like Lisp because it was designed for humans first, especially young humans.

But the bones show through:    
	1.	Prefix function application (verbs first)  
	2.	List-centered data thinking  
	3.	Quoting and symbol/value separation  
	4.	Comfort with recursion  
	5.	A path toward code-as-data  

So the sentence "Logo is a Lisp dialect" is not a joke. It is a reminder that programming languages can share a soul even when they do not share a wardrobe.

## Back where it all begin

In Class IV, we had no idea that we were accidentally being taught one of the deepest ideas in CS, that lists can represent both data and instructions, and the difference between them is often just "how you choose to evaluate."

---

## Notes and references

[^1]: St. George's College, Agra
[^2]: Agra is a city situated on the banks of River Yamuna, around 200Km south of Delhi, in the state of Uttar Pradesh in India. It was once a Mughal capital and is famous for mostly Mughal Architecture with two famous buildings of that time being - Taj Mahal, a mausaoleum build by Shahjahan for his wife and Fatehpur Sikri, the fort that was eventually abandoned by Akbar.
[^3]: My memory is vague on this and I have not corroborated this with the school. 
[^4]: I don't remember the version of Logo, whether it was UCB Logo or MSW Logo. More information about the language can be found [here](https://el.media.mit.edu/logo-foundation/index.html).
[^5]: Descriptions of Logo as a Lisp dialect / Lisp-family language are common in historical and documentation sources. A good starting point is the MIT Logo Foundation page and the UCBLogo documentation. (URLs for easy copying: https://el.media.mit.edu/logo-foundation/ and https://people.eecs.berkeley.edu/~bh/logo.html)
[^6]: In Linguistic, we often talk about Deep Structures and surface structures. Surface structure is how the language is spoken in contrast to Deep structure which deals with the deeper meaning. [Deep and Surface Structures](https://en.wikipedia.org/wiki/Deep_structure_and_surface_structure?wprov=sfti1#)