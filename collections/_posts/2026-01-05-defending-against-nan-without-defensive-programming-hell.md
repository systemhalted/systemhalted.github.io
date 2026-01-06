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

NaN is not a bug. It is a receipt.

A little slip of paper IEEE 754 hands you after your math did something undefined, and instead of crashing the universe, the CPU says, "Not a number, friend," and keeps walking.

That is noble. That is also how NaN quietly sneaks into your systems, wears your log files as a cape, and turns your dashboards into modern art.

This post is about defending against NaN without turning your codebase into a forest of anxious `if (isNaN)` tripwires.

## The shape of the beast

So what exactly is this receipt for?

NaN stands for "Not a Number." Expand it once, then treat it like a proper noun: NaN.

You get NaN from operations that have no real number answer, such as:
	1.	0.0 / 0.0  
	2.	Math.sqrt(-1.0)  
	3.	Math.log(-1.0)  
	4.	Any operation that already contains NaN, because NaN is contagious in the best and worst ways  
 
Java follows IEEE 754 here. The JVM will not throw an exception for most floating point invalid operations. It will produce NaN (or Infinity), and your program continues with a tiny invisible crack in reality.

Here is the first mind-bending property:

NaN is not equal to anything, including itself.

{% highlight java %}
double x = Double.NaN;

System.out.println(x == x);              // false
System.out.println(Double.isNaN(x));     // true
System.out.println(x < 0);              // false
System.out.println(x > 0);              // false
System.out.println(x == 0);             // false
{% endhighlight %}

So NaN does not behave like a "value" in the usual sense. It behaves like a signal masquerading as a value.

That disguise is the whole problem.

## Defensive programming hell: "Checkpoint Syndrome"

The naive reaction is understandable:

You discover NaN in production.  
You add checks.  
You discover it again.  
You add more checks.  
Eventually every function looks like airport security staffed by anxious squirrels.  

You get code like:

{% highlight java %}
double price = computePrice(input);
if (Double.isNaN(price) || Double.isInfinite(price)) {
    // shrug, return 0?
}
{% endhighlight %}

This is Checkpoint Syndrome because:  
	1.	It spreads everywhere.  
	2.	It hides the real cause. The first invalid operation is upstream.  
	3.	It forces you to decide "what now" in a dozen places, inconsistently.  
	4.	It often converts "unknown" into "zero," which is how financial bugs are born.  

The antidote is not "more checks." The antidote is better geometry - put the checks where they matter, once, with intent.  

## The core principle: validate at the edges, compute in the middle

![Diagram showing validation at boundaries and a clean computation core.]({{ "/assets/images/2026-01-05-core-principles.png" | relative_url }})

Most NaN outbreaks begin at boundaries:  
	1.	Parsing and deserialization (CSV, JSON, user input, partner payloads)  
	2.	Sensor-style data (telemetry, percentages, rates)  
	3.	Divide by something that might be zero or missing  
	4.	"This should never happen" conversions (and then it happens)  

Your best defense is to establish a simple contract:

Inside the computation core, all doubles are finite unless explicitly documented otherwise.

The computation core is the part of your system that should be blissfully boring: the pure math functions, the algorithms, the business logic that assumes validated inputs. The place where you want to reason about correctness without also doing border control.

That means you concentrate NaN handling in a few choke points.

## Pattern 1: "Finite by default" as a guardrail

Create a tiny helper that asserts finiteness.

{% highlight java %}
static double requireFinite(double x, String name) {
    if (!Double.isFinite(x)) {
        throw new IllegalArgumentException(name + " must be finite, got " + x);
    }
    return x;
}
{% endhighlight %}

**Why `Double.isFinite()` is your single weapon:** It returns `true` only when `x` is neither NaN nor Infinity - exactly what "finite by default" means. You don't need two checks (`isNaN` and `isInfinite`). You need one: "is this a normal, usable number?"

Use it at public boundaries and layer transitions, not inside every private method.

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

This gives you three wins:  
	1.	The failure is loud and early.  
	2.	The computation stays clean.  
	3.	The exception points to a real contract violation, not a mysterious downstream symptom.  

## Pattern 2: Separate "invalid" from "zero" with a result type

Sometimes you cannot throw. Sometimes your caller needs to continue, but also needs to know the answer is invalid.

So represent that truth explicitly.

In Java, you can use a sealed interface to create a true disjunctive type (see my [post on disjunctive types](https://systemhalted.in/2025/11/25/disjuntive-types/) for the full story):

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

Now NaN is no longer a stealth signal. Invalid states are impossible to construct incorrectly, and the compiler enforces exhaustive handling.

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

The point is not the exact type. The point is the discipline: invalid is a first-class outcome, and the type system prevents you from accidentally treating it as valid.


## Pattern 3: Domain types that make NaN impossible

Many doubles in business systems are not "real numbers in the wild."
They are money, rates, counts, durations, percentages.

Those are not great candidates for raw double.

A few examples:  
	1.	Money: store cents as long, or use BigDecimal where precision matters  
	2.	Counts: long or int  
	3.	Percentages: maybe basis points as int (one basis point = 0.01%, so 550 bps = 5.50%)  
	4.	Durations: java.time.Duration  

When you tighten types, you reduce the surface area where NaN can even appear. That is the most reliable NaN defense there is: make the invalid state unrepresentable.

NaN cannot enter a long. It can only stand outside and glare.

## Pattern 4: Decide where Infinity is acceptable

Part 5 covered Infinity and signed zero. Here is the practical angle.

Infinity can be a legitimate signal in some domains:  
	1.	"Unlimited" limit  
	2.	"Unbounded" score  
	3.	A mathematical asymptote that you intentionally model  

But if your domain does not explicitly accept Infinity, treat it exactly like NaN - reject both at the boundary with `Double.isFinite()`. This is why `requireFinite` uses that single check: it enforces "no NaN, no Infinity" in one line.

If you *do* need to distinguish between NaN and Infinity (rare), check them separately. But for most code, "not finite" is the only distinction that matters.

The bug pattern is when Infinity is tolerated accidentally and later multiplied into a massive number that looks plausible, which is how nonsense becomes confident nonsense.

## Pattern 5: Centralize sanitization, but do not lie

Sometimes you must "sanitize" bad inputs, especially with messy external data.
The key is: do it once, do it centrally, and record what you did.

A dangerous sanitization is this:

{% highlight java %}
double safe = Double.isFinite(x) ? x : 0.0;
{% endhighlight %}

That turns "unknown" into "zero," and zero is not neutral in most systems.

A safer pattern is to either:  
	1.	Drop the datapoint (for aggregates), and count it   
	2.	Mark the result invalid  
	3.	Fall back to a documented default that has real meaning, and log it  

Example for aggregation:  

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

Notice the honesty: if nothing valid exists, we do not pretend.

## Third-party libraries: when NaN arrives by mail

Sometimes NaN isn't born in your code. It is delivered.

The most common culprit is calling math functions that can legitimately return NaN for part of their domain, and forgetting that you just crossed into "inputs must be validated" territory again.

Check immediately after the call, while you still have context.

{% highlight java %}
double result = Math.sqrt(userInput);

// JDK math functions and third-party libs can return NaN.
// Validate the output right away, at the point of crossing.
requireFinite(result, "sqrt result");
{% endhighlight %}

This pattern generalizes: any time you call out to code you don't control (libraries, services, models, partner feeds), treat the return value as a new boundary.

## Finding the first NaN, not the last one

A common tragedy is you only detect NaN at the end, in a report, after ten transformations. At that point NaN is the smoke, not the fire.

Two practical tricks:

### Add "tripwire assertions" in debug builds

In places where NaN should never exist, assert it in tests and in non-production modes.

{% highlight java %}
static void assertFinite(double x, String name) {
    if (!Double.isFinite(x)) {
        throw new AssertionError(name + " became non-finite: " + x);
    }
}
{% endhighlight %}

Call it after major computation steps in critical algorithms, especially ones that are numerically sensitive.

### Log with context once, not everywhere

If you need observability, centralize it.
For example, in an input adapter:

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

This is where you actually still have context: the original data and the identity of the source.

Downstream, you mostly have regret.

## A small NaN hygiene checklist
	1.	Use Double.isFinite at boundaries where values enter your system or cross layers
	2.	Keep computation code clean; assume finite inputs inside the core
	3.	Do not convert invalid to zero unless the domain definition says it is correct
	4.	Prefer domain types over raw doubles when the value is not truly "a real number"
	5.	When you must degrade gracefully, return an explicit invalid result, not a silent sentinel
	6.	Instrument the boundary where you reject or drop invalids, so you can find the upstream cause

NaN is not evil. It is your system trying to stay alive after stepping on a rake.

Your job is not to sprinkle rakes with warning stickers.
Your job is to stop leaving rakes in the hallway.



