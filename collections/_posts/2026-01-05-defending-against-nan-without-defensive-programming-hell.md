---
layout: post
title: "Part 6: Defending Against NaN Without Defensive Programming Hell"
type: post
published: true
comments: true
categories:
  - Computer Science
  - Software Engineering
  - Technology
  - Series 4 - Floating Point Without Tears
tags: [java, floating-point, ieee-754, nan, validation, reliability]
featured_image: assets/images/featured/2026-01-05-defending-against-nan-without-defensive-programming-hell.svg
featured_image_alt: "Part 6 hero image: Bold warning against Checkpoint Syndrome, the anti-pattern of scattering NaN checks throughout code. Central danger symbol with radiating lines represents validation chaos. Contrasts bad pattern (red if-isNaN checks) with good pattern (green requireFinite at boundaries)."
featured_image_caption: "NaN spreads like wildfire when you scatter if (isNaN) checks everywhere. The cure? Validate once at your system's boundaries, then let your computation core stay blissfully clean."
description: "Learn how to handle NaN and Infinity in Java without scattering if (isNaN) checks everywhere. Five practical patterns: boundary validation with Double.isFinite(), result types, domain types, centralized sanitization, and detecting NaN at its source. Avoid Checkpoint Syndrome and keep your computation code clean."
---
*This post is part of my [Floating Point Without Tears](https://systemhalted.in/categories/#cat-series-4-floating-point-without-tears) series on how Java numbers misbehave and how to live with them.*

When IEEE 754 arithmetic encounters an operation for which there is no real-number answer — dividing zero by zero, taking the square root of a negative number, and so on — it does not throw an exception. Instead, it produces a special value called NaN, short for "Not a Number," and the program continues running as if nothing in particular had happened. This is, as a piece of language design, both a strength and a quiet curse: it allows numerical code to keep flowing in the presence of locally invalid operations, but it also means that NaN tends to slip downstream silently and only surface much later, in log files, in metrics, and on dashboards, long after the operation that actually produced it has scrolled out of view.

The temptation, on first encountering this behaviour, is to start sprinkling `if (isNaN)` checks throughout the codebase as a defence. This post is, in a sense, about doing the opposite of that — about defending against NaN structurally, using a small number of checks placed deliberately at the right boundaries, rather than scattering a defensive layer through every function in the system.

## The shape of the beast

NaN, as the name suggests, is what IEEE 754 hands back from operations that have no meaningful real-number answer. The canonical examples are familiar enough — dividing `0.0` by `0.0`, taking the square root of a negative number, taking the logarithm of a negative number — but there is a fourth source that is, in practice, more important than any individual mathematical case: any operation that already involves a NaN will itself produce a NaN. NaN is contagious, in both the best and the worst senses of the word, and that contagion is the mechanism by which a single invalid operation upstream can quietly poison everything that flows from it.

Some of the operations that produce NaN are:

	1.	0.0 / 0.0  
	2.	Math.sqrt(-1.0)  
	3.	Math.log(-1.0)  
	4.	Any operation that already contains NaN, because NaN is contagious in the best and worst ways  
 
Java follows IEEE 754 in all of this. The JVM does not, for the most part, throw an exception when a floating-point operation is invalid; it produces NaN or Infinity and lets the program continue, which is another way of saying that what you are looking at is a silent error.

There is one further property of NaN that catches almost everyone the first time they encounter it. NaN is not equal to anything, not even to itself.

{% highlight java %}
double x = Double.NaN;

System.out.println(x == x);              // false
System.out.println(Double.isNaN(x));     // true
System.out.println(x < 0);              // false
System.out.println(x > 0);              // false
System.out.println(x == 0);             // false
{% endhighlight %}

NaN, in other words, does not really behave like a value in the ordinary sense; it is more accurately understood as a signal that has, by the design of the floating-point system, been forced to masquerade as a value. The fact that it wears that disguise convincingly is the source of most of the practical trouble that NaN goes on to cause in production systems.

## Defensive programming hell, or what I call "Checkpoint Syndrome"

The instinctive reaction to discovering NaN in production is, I think, entirely understandable. You find a NaN in a log, trace it back to a particular code path, add an `isNaN` check there, deploy the fix, and move on. The trouble is that, almost without exception, the next NaN that shows up will not be in the same place — it will be in some other path that touches the same data — and so another check goes in. Repeat this process for a few months and you end up with a codebase in which essentially every function is doing its own defensive validation of every input it receives, often with slightly different responses to the same underlying condition.

The result tends to look something like this:

{% highlight java %}
double price = computePrice(input);
if (Double.isNaN(price) || Double.isInfinite(price)) {
    // shrug, return 0?
}
{% endhighlight %}

This is what I have come to think of as Checkpoint Syndrome, and the problem with it goes well beyond the visual noise. It is something closer to a small architectural disaster: the checks have a way of spreading everywhere, and yet, despite their ubiquity, they almost never point at the real cause of the bug, because by the time NaN reaches the function being checked, the operation that originally produced it is several layers upstream and is no longer visible at the call site. Each defensive site is also forced to make its own decision about what to do when the check fails, and those decisions tend to drift apart over time, so a single class of upstream bug ends up being silently handled in a dozen inconsistent ways throughout the codebase.

Worst of all — and this is where Checkpoint Syndrome most reliably produces actual financial bugs — the easiest "fix" at any individual site is to convert the invalid value to zero. That has the convenient property of making the immediate symptom go away, while quietly turning "we do not know" into "definitely zero" in every downstream calculation that follows.

The antidote to all of this is not, as it might first appear, to add more checks. The antidote is to place fewer checks but to place them where they actually matter — at the boundaries where invalid values either enter the system or are first produced, once, deliberately, and with a documented response.

## The core principle: validate at the edges, compute in the middle

![Diagram showing validation at boundaries and a clean computation core.]({{ "/assets/images/2026-01-05-core-principles.png" | relative_url }})

Most NaN outbreaks begin at boundaries:

	1.	Parsing and deserialization (CSV, JSON, user input, partner payloads)  
	2.	Sensor-style data (telemetry, percentages, rates)  
	3.	Divide by something that might be zero or missing  
	4.	"This should never happen" conversions (and then it happens)  

The most useful thing you can do in response to this, in my experience, is to establish a single simple contract that the rest of the system can rely on: inside the computation core, all doubles are finite unless explicitly documented otherwise. The computation core is the part of the system that should be allowed to be blissfully boring — the pure math, the algorithms, the business logic that operates on already-validated inputs — and it is the place where you most want to be able to reason about correctness without simultaneously doing border control.

The practical consequence of that contract is that NaN handling becomes concentrated in a small number of choke points, rather than spread thinly across the codebase.

## Pattern 1: "Finite by default" as a guardrail

The simplest expression of this discipline is a small helper that asserts finiteness explicitly:

{% highlight java %}
static double requireFinite(double x, String name) {
    if (!Double.isFinite(x)) {
        throw new IllegalArgumentException(name + " must be finite, got " + x);
    }
    return x;
}
{% endhighlight %}

`Double.isFinite()` is, for this purpose, the only check you actually need. It returns `true` only when its argument is neither NaN nor Infinity, which is exactly what "a normal, usable number" means in most contexts. There is rarely any value in writing two separate checks for `isNaN` and `isInfinite` when a single call to `isFinite` captures both conditions.

The pattern, then, is to use `requireFinite` at public boundaries and at layer transitions, rather than inside every private method:

{% highlight java %}
public double monthlyPayment(double principal, double annualRate, int months) {
    requireFinite(principal, "principal");
    requireFinite(annualRate, "annualRate");
    if (months <= 0) throw new IllegalArgumentException("months must be positive");

    double r = annualRate / 12.0;

    // Standard annuity formula:
    //   P = L * [r(1+r)^n] / [(1+r)^n - 1]
    // Rewritten with a negative exponent:
    //   P = L * r / (1 - (1+r)^(-n))
    // Same math, often friendlier numerically for large n.
    return principal * r / (1.0 - Math.pow(1.0 + r, -months));
}
{% endhighlight %}

What you get from this approach is, I think, three things worth having at the same time. The failure becomes loud and early, rather than silent and downstream. The body of the computation stays free of validation noise. And when the exception does fire, it points at a real contract violation — a specific named argument coming in non-finite — rather than at some mysterious symptom many layers later in the call stack.

## Pattern 2: Separate "invalid" from "zero" with a result type

There are situations in which you cannot reasonably throw — typically because the caller is processing a stream of inputs and needs to continue regardless of whether any individual one is valid, while still being able to tell which ones were not. In those situations, the right move is usually to represent the distinction explicitly in the return type, rather than overloading a numeric value to mean both "result" and "no result."

In Java, you can use a sealed interface to construct a true disjunctive type, of which I have written a [longer post](https://systemhalted.in/2025/11/25/disjuntive-types/) for the full story:

{% highlight java %}
sealed interface CalcResult permits CalcResult.Valid, CalcResult.Invalid {
    
    record Valid(double value) implements CalcResult {
        public Valid {
            // Enforce finite values in Valid variant
            if (!Double.isFinite(value)) {
                throw new IllegalArgumentException("Valid result must be finite");
            }
        }
    }
    
    record Invalid(String reason) implements CalcResult {}
    
    // Convenience factory methods
    static Valid ok(double value) {
        return new Valid(value);
    }
    
    static Invalid failed(String reason) {
        return new Invalid(reason);
    }
}
{% endhighlight %}

With a type of this shape in place, NaN is no longer a stealth signal hiding inside a numeric channel. An invalid result is a first-class outcome of its own, the `Valid` variant cannot be constructed with a non-finite value, and the compiler can be made to enforce exhaustive handling at every consumption site.

{% highlight java %}
CalcResult safeDivide(double a, double b) {
    if (!Double.isFinite(a) || !Double.isFinite(b)) {
        return CalcResult.failed("non-finite input");
    }
    if (b == 0.0) {
        return CalcResult.failed("division by zero");
    }
    return CalcResult.ok(a / b);
}

// Pattern matching is exhaustive - compiler forces you to handle both cases
CalcResult result = safeDivide(10.0, 2.0);
switch (result) {
    case CalcResult.Valid(double v) -> 
        System.out.println("Result: " + v);
    case CalcResult.Invalid(String reason) -> 
        System.err.println("Failed: " + reason);
    // No default needed - this is exhaustive
}
{% endhighlight %}

The exact shape of the type is, in the end, less important than the discipline it expresses. What matters is that "invalid" is treated as a first-class outcome that the type system insists be handled, rather than as a special value that callers can quietly forget to check for.

## Pattern 3: Domain types that make NaN impossible

It is also worth observing that many of the doubles in business systems are not really "real numbers in the wild." They are money, rates, counts, durations, and percentages — values which have far more structure than `double` is capable of representing, and which therefore tend to make poor candidates for raw `double` storage in the first place.

A few examples of the better choice in each case:

	1.	Money: store cents as long, or use BigDecimal where precision matters  
	2.	Counts: long or int  
	3.	Percentages: maybe basis points as int (one basis point = 0.01%, so 550 bps = 5.50%)  
	4.	Durations: java.time.Duration  

Tightening the types in this way reduces the surface area on which NaN can even appear in the first place. This is, in the end, the most reliable form of NaN defence available, and it has the additional virtue of being entirely structural: it is enforced by the compiler, rather than by the discipline of the next person to touch the code. A `long`, after all, simply cannot hold NaN — the language will not allow it.

## Pattern 4: Decide where Infinity is acceptable

Part 5 of this series covered Infinity and signed zero in some detail. The practical question, at this stage, is what to do about Infinity in everyday code, and the answer turns mostly on whether your domain has any legitimate use for it.

Infinity is sometimes a meaningful signal:

	1.	"Unlimited" limit  
	2.	"Unbounded" score  
	3.	A mathematical asymptote that you intentionally model  

If your domain does not explicitly accept Infinity as a meaningful value, however, the right thing to do is to treat it exactly as you would treat NaN — reject it at the boundary, using `Double.isFinite()`. This is precisely why the `requireFinite` helper above checks for finiteness rather than for `isNaN` alone: it enforces the rule "no NaN, no Infinity, full stop" in a single line. In the rare cases in which you genuinely need to distinguish between NaN and Infinity, you can still do so by checking each separately, but for the great majority of code, the only useful distinction is finite versus not-finite.

The bug pattern to be alert to is the case where Infinity is tolerated accidentally — quietly admitted into the computation core because no one thought to reject it — and is then multiplied or scaled into a very large number that happens to look plausible at a glance. That is, in effect, how nonsense becomes confident-looking nonsense, and it is harder to catch downstream than NaN, because at least NaN propagates obviously.

## Pattern 5: Centralize sanitization, but do not lie

There are also situations in which sanitization is genuinely required, particularly when dealing with messy external data over which you have no control. The two principles I would offer, having been bitten by both, are: do the sanitization once, in a centralised place, and be honest about what you actually did.

The dangerous form of sanitization is the one that looks reasonable at first glance:

{% highlight java %}
double safe = Double.isFinite(x) ? x : 0.0;
{% endhighlight %}

The problem with this pattern is that it converts "we do not know" into "definitely zero", and zero is rarely a neutral value in any system that does arithmetic on it. A safer set of options is to either drop the offending datapoint outright (and to count it, so the volume of dropped values is observable), to mark the result as invalid using one of the result types described above, or to fall back to a documented default that has actual meaning in the domain — and, in any case, to log what happened so that the upstream cause can eventually be addressed.

A common example in aggregation is something like this:

{% highlight java %}
double averageFinite(double[] xs) {
    double sum = 0.0;
    int n = 0;

    for (double x : xs) {
        if (Double.isFinite(x)) {
            sum += x;
            n++;
        }
    }

    // Honest answer: no valid data means undefined result.
    if (n == 0) return Double.NaN;

    return sum / n;
}
{% endhighlight %}

The honesty of the function consists in the last detail: when there is no valid data to average, the function returns NaN rather than zero. NaN is, in this case, the right answer — it is exactly what "undefined" means — and silently substituting zero would, once again, be a way of pretending to know something the function actually does not.

## Third-party libraries: when NaN arrives by mail

Not every NaN is born in your own code. Some of them are delivered.

The most common cause of imported NaN is calling a math function that can legitimately return NaN for part of its domain — `Math.sqrt`, `Math.log`, and so on — and then forgetting that the moment you call out to such a function you have, in effect, crossed a boundary again, and the same boundary discipline applies. The fix is to validate the result immediately, at the point of crossing, while you still have full context about what was being computed:

{% highlight java %}
double result = Math.sqrt(userInput);

// JDK math functions and third-party libs can return NaN.
// Validate the output right away, at the point of crossing.
requireFinite(result, "sqrt result");
{% endhighlight %}

The pattern generalises beyond JDK math: any time you call out to code you do not control — libraries, services, model inference endpoints, partner data feeds — the return value is best treated as a fresh boundary, with the same kind of validation you would apply to any other external input. The principle being preserved here is simply that the computation core gets to assume validated inputs, and any time something crosses into the core from elsewhere, the responsibility for validation falls on the crossing point.

## Finding the first NaN, not the last one

There is a particular tragedy that tends to play out in long-lived systems, in which NaN is only detected at the very end of a long chain of transformations — in a report, on a dashboard, or in a downstream consumer — and the team then has to work backwards through ten transformations to find the operation that originally produced it. By that point, the NaN you are looking at is the smoke; the fire was several layers upstream, and the hard part of the bug is reconstructing how the smoke got to where it is now.

Two practical habits help with this:

### Add "tripwire assertions" in debug builds

In places where NaN should never legitimately exist, it is worth asserting that fact explicitly during development and in tests, so that the first appearance of NaN fails loudly rather than silently propagating:

{% highlight java %}
static void assertFinite(double x, String name) {
    if (!Double.isFinite(x)) {
        throw new AssertionError(name + " became non-finite: " + x);
    }
}
{% endhighlight %}

This is particularly worthwhile after major computation steps in numerically sensitive algorithms, where the cost of the assertion is negligible and the benefit of catching the first bad value early is considerable.

### Log with context once, not everywhere

If the system needs observability into NaN-related rejections — and most production systems eventually do — the right place for that observability is at the boundary where the rejection happens, because that is where the original context still exists. An input adapter is a good example:

{% highlight java %}
double parseRate(String raw) {
    double x = Double.parseDouble(raw);
    if (!Double.isFinite(x)) {
        // log raw payload id, customer id, partner id, etc.
        throw new IllegalArgumentException("rate must be finite");
    }
    return x;
}
{% endhighlight %}

This is the point at which you still have access to the raw payload, the source identity, and any correlating identifiers; once the value has flowed through several layers of the application, all of that context tends to be lost. Logging at the boundary, rather than at the point of eventual symptom, is therefore both cheaper and more useful.

## A small NaN hygiene checklist

By way of summary, the practices that have served me well in dealing with NaN in long-running systems are roughly these:

	1.	Use Double.isFinite at boundaries where values enter your system or cross layers
	2.	Keep computation code clean; assume finite inputs inside the core
	3.	Do not convert invalid to zero unless the domain definition says it is correct
	4.	Prefer domain types over raw doubles when the value is not truly "a real number"
	5.	When you must degrade gracefully, return an explicit invalid result, not a silent sentinel
	6.	Instrument the boundary where you reject or drop invalids, so you can find the upstream cause

NaN, taken on its own terms, is not really an enemy. It is the floating-point system's way of telling you that something invalid happened upstream and that the math, in good faith, could not produce a real-number answer. The defensive task is therefore not to suppress that signal everywhere it appears, but to listen to it where it first appears, deal with it deliberately at the boundary, and let the rest of the system rely on the contract that the boundary enforces. Validate at the edges, keep the core clean, and resist, as steadily as you can, the temptation to silently turn unknown into zero.
