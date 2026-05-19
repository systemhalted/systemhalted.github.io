---
layout: post
title: "Part 7: Kahan Summation - A Better sum() for Java Streams"
type: post
published: true
comments: true
toc: true
categories:
  - Computer Science
  - Software Engineering
  - Technology
  - Series 4 - Floating Point Without Tears
tags: [java, floating-point, ieee-754, kahan, numerical-analysis, streams, collector]
description: "Learn why naive summation loses digits and how Kahan compensated summation helps. Includes Java Stream integration, test strategies, and when to use BigDecimal instead."
featured_image: /assets/images/featured/2026-01-11-kahan-summation-java-streams.png
featured_image_alt: 'Retro tech illustration of floating point summation: a terminal showing "S = 0.0" and "S = S + Yᵢ", a large glowing sigma (Σ), and a result of "1000000.0" over a grid with scattered numeric crumbs; subtle watermark "@systemhalted.in" in the lower right.'
featured_image_caption: "Kahan summation in one image: the sum grows, the crumbs fall off, and compensation helps you sweep them back."
---

*This post is part of my [Floating Point Without Tears](https://systemhalted.in/categories/#cat-series-4-floating-point-without-tears) series on how Java numbers misbehave and how to live with them.*

In [Part 6](https://systemhalted.in/2026/01/05/defending-against-nan-without-defensive-programming-hell/) of this series, we looked at how to defend against NaN by validating values at boundaries rather than scattering checks throughout the code. This post is about a different and, in its own way, sneakier kind of failure mode in floating-point arithmetic — the case where your sum is computed correctly at every individual step, every individual operation does exactly what the standard says it should, and the final answer is still meaningfully wrong.

___

There is a quiet bug that hides inside almost every large numerical reduction in production code, and it has, in my experience, almost nothing to do with mistakes in logic and almost everything to do with how floating-point addition is forced to behave. Floating point has fixed precision: every addition rounds back to a fixed number of significant digits, and the bits that do not fit are discarded. Most of the time, the discarded bits are too small to matter. Some of the time — particularly when you add a large number of values together, or when the values you are adding span many orders of magnitude — the cumulative effect of those tiny dropped bits becomes large enough to be visible in the answer.

This post is about the full story of **Kahan summation**, which is a small algorithmic trick with a surprisingly large impact on this kind of error. Kahan summation does not, and cannot, make floating-point arithmetic exact; what it does is keep your running totals from quietly losing meaningful contributions when you add many numbers, by tracking the bits that rounding has thrown away and folding them back into the next operation.

## The innocent-looking loop

The classic numerical-analysis textbook example for this kind of error is, for historical reasons, usually written in Fortran — it is the lingua franca of mid-twentieth-century numerics — and it looks innocuous enough that it is easy to read past it without realising what it is about to do.

{% highlight fortran %}
S = 0.0
DO 4 I = 1, N
  YI = ...
4 S = S + YI
{% endhighlight %}

The whole drama, such as it is, lives in the last line: `S = S + YI`. People then drop in a line that, at first reading, sounds slightly mystical:

> Rounding or truncation in the addition can contribute to a loss of almost $\log_{10}(N)$ significant decimal digits in S.

The $\log_{10}(N)$ in that sentence does not, however, come from any sort of wizardry. It is simply what happens when fixed precision collides with a running total that keeps growing — the floating-point grid on which the running total can land gets coarser as the total gets larger, and so the smallest things you are still trying to add to it get progressively harder to see.

## Why you can lose about log10(N) digits

Suppose, for the sake of intuition, that we are working in base-10 floating point with **p significant decimal digits**. (IEEE 754 is base 2, but the intuition transfers cleanly enough that working in base 10 is worth it for the explanation.) Suppose further that the `YI` values are roughly the same size and mostly the same sign, so that the partial sums genuinely grow rather than cancelling each other out, and let `|Y|` denote a typical magnitude.

After `N` terms, then, the true sum is roughly:

$$
S_{\text{true}} \approx N \cdot Y
$$

And here is the key floating-point constraint to keep in mind: a `p`-digit floating number around magnitude `|S|` cannot represent arbitrarily small changes. Near `S`, the spacing between representable values is approximately:

$$
\Delta S \approx |S| \cdot 10^{-p}
$$

It helps to think of $\Delta S$ as the width of the grid lines at the altitude where `S` happens to live. When you compute `S = S + YI`, the result is rounded back onto that grid, and any increment that is much smaller than $\Delta S$ at that altitude can simply vanish, because there is no representable value between `S` and `S + YI` in the new precision regime.

By the end of the loop, `|S| \approx N|Y|`, so the grid spacing near the final sum is:

$$
\Delta S \approx (N|Y|)\,10^{-p}
$$

Comparing the grid spacing to the size of a typical addend gives:

$$
\frac{\Delta S}{|Y|} \approx N \cdot 10^{-p} = 10^{\log_{10}N - p}
$$

That ratio, in the end, is what the textbooks are getting at. Multiplying by `N` shifts magnitudes by $\log_{10}(N)$ decimal digits, which means that as the running sum grows by a factor of `N`, the rounding grid spacing grows by exactly the same factor. Relative to the scale of the things you are still trying to add, you have therefore effectively lost about $\log_{10}(N)$ digits of useful precision. Another way to say the same thing is:

$$
\text{useful digits left at the addend scale} \approx p - \log_{10}N
$$

### A concrete gut punch

Suppose, to make this less abstract, that you are working with about `p = 7` significant decimal digits — roughly single-precision territory — and you sum `N = 10^6` numbers, each of size about 1.

$\log_{10}(10^6) = 6$

Which leaves you with roughly:

$7 - 6 = 1$ meaningful decimal digit at the scale of 1

By the time `S` reaches around one million, the grid spacing near `S` is roughly:

$10^6 \cdot 10^{-7} = 10^{-1} = 0.1$

So adding `0.01` to `S` at that point can literally do nothing at all — the increment is smaller than the grid spacing in the precision regime where the running total currently lives, and it gets rounded away. The problem, in other words, is not really the single rounding step; it is the cumulative effect of rounding many million times while the running total continues to inflate.

## A quick demo: sums that look reasonable and are still wrong

Here is a small example of the same kind of cancellation, in Java this time:

{% highlight java %}
double x = 1e16;
double naive = (x + 1.0) + 1.0 - x;   // commonly prints 0.0
System.out.println(naive);
{% endhighlight %}

The two `+ 1.0` additions in this expression happen while the running value is around `1e16`, and at that scale `1.0` is, in fact, smaller than the spacing between representable doubles. The two ones, therefore, fall through the cracks of the grid entirely, and the answer that arrives back is `0.0` rather than the `2.0` that ordinary arithmetic would have produced.

This is, importantly, not a curious corner case that only shows up in exam questions. If your system does any kind of analytics, pricing, telemetry, risk computation, recommendations, or ranking — anything where `N` becomes large in routine operation — this kind of error is the default failure mode hiding inside what looks like a perfectly innocent reduction.

## Kahan summation: track what gets dropped

Kahan summation is, in technical terms, an instance of **compensated summation**. The idea is to keep two running numbers instead of one:

* `sum`: the running total, the way you would normally maintain it
* `c`: a compensation term that records what rounding threw away on the previous addition

The first holds the running total at full machine precision; the second holds an estimate of the low-order bits that were lost on the most recent addition, so that those lost bits can be folded back into the next addition rather than disappearing forever.

### The algorithm

Given a new addend `x`, the algorithm performs three steps in sequence: it adjusts the addend by what was lost on the previous step, it adds the adjusted addend to the running total, and it then estimates how much was lost on this step and stores that estimate as the new compensation.

{% highlight text %}
y = x - c
t = sum + y
c = (t - sum) - y
sum = t
{% endhighlight %}

That, taken on its own terms, is the whole trick. It does not change the underlying floating-point rules — additions are still rounded, the precision is still finite — but it changes the way you accumulate so that the rules hurt you less, by keeping a small ledger of what they have already cost you and applying it as a correction on the next operation.

## Java implementation: a small accumulator with big consequences

### The accumulator type

A reasonable Java implementation of the algorithm above is a small accumulator object that exposes the operations one would expect of any reduction primitive — adding a single value, combining with another instance of itself, and producing a final result.

{% highlight java %}
public final class KahanAccumulator {
  private double sum;
  private double c; // compensation for lost low-order bits

  public void add(double x) {
    double y = x - c;
    double t = sum + y;
    c = (t - sum) - y;
    sum = t;
  }

  public void combine(KahanAccumulator other) {
    // Merge another partial sum into this one.
    // This improves accuracy, but the result is still order-dependent.
    this.add(other.sum);
    this.add(other.c);
  }

  public double value() {
    return sum;
  }
}
{% endhighlight %}

One thing worth saying clearly here, before anyone is tempted to oversell what Kahan summation buys: Kahan improves accuracy substantially, but **floating-point addition is still not associative**, which means that parallel reductions running over the same data can still produce different totals from one run to the next, simply because the order in which the partial sums get combined varies. Kahan makes that wobble considerably smaller; it does not make it impossible.

## Using it with Streams

There are two natural ways to integrate this accumulator with the Java Streams API, depending on whether you happen to have a primitive `DoubleStream` or a boxed `Stream<Double>`.

### Option A: DoubleStream.collect (best for primitive streams)

`DoubleStream` has its own `collect` overload that avoids the boxing cost of the generic `Collector` machinery, which makes it the better choice when you already have a primitive stream:

{% highlight java %}
import java.util.stream.DoubleStream;

public final class Kahan {

  private Kahan() {}

  public static double sum(DoubleStream stream) {
    KahanAccumulator acc = stream.collect(
        KahanAccumulator::new,
        KahanAccumulator::add,
        KahanAccumulator::combine
    );
    return acc.value();
  }
}
{% endhighlight %}

Usage looks like the obvious thing:

{% highlight java %}
double s1 = Kahan.sum(DoubleStream.of(0.1, 0.2, 0.3));
double s2 = Kahan.sum(myDoubleStream.parallel()); // allowed, order still not fixed
{% endhighlight %}

### Option B: a Collector (nice ergonomics for boxed streams)

When you already have a `Stream<Double>` for some reason — typically because the upstream code is using boxed types — a `Collector` is more convenient and idiomatic:

{% highlight java %}
import java.util.stream.Collector;

public final class KahanCollectors {

  private KahanCollectors() {}

  public static Collector<Double, KahanAccumulator, Double> kahanSummingDouble() {
    return Collector.of(
        KahanAccumulator::new,
        (acc, x) -> acc.add(x),
        (a, b) -> { a.combine(b); return a; },
        KahanAccumulator::value
    );
  }
}
{% endhighlight %}

Usage, again, is the usual thing:

{% highlight java %}
double s = myStreamOfDoubles.collect(KahanCollectors.kahanSummingDouble());
{% endhighlight %}

## Correctness: what to test, and what not to promise

It is worth being precise, when introducing this kind of utility into a codebase, about what it does and does not promise, because the difference between the two is the source of most production surprises in this space.

### What you should promise

* Better accuracy than naive summation for large `N` and wide dynamic ranges
* Explicit behavior you control and can review in code

### What you should not promise

* Bit-for-bit deterministic results in parallel streams
* Exactness for money or decimal accounting

### JUnit test idea: compare against a higher-precision reference

`BigDecimal` is not, strictly speaking, a perfect oracle for binary floating point — it represents numbers in base 10 — but it is a very useful reference when you want to confirm that one summation strategy is drifting more than another, since `BigDecimal` arithmetic has effectively unlimited precision for the operations involved here.

{% highlight java %}
import static org.junit.jupiter.api.Assertions.*;
import java.math.BigDecimal;
import java.util.Random;
import java.util.stream.DoubleStream;
import org.junit.jupiter.api.Test;

public class KahanAccumulatorTest {

  @Test
  void kahan_is_usually_better_than_naive_on_wide_range_data() {
    Random r = new Random(0);

    double[] xs = DoubleStream.generate(() -> {
      double sign = r.nextBoolean() ? 1.0 : -1.0;
      double mag = Math.pow(10.0, r.nextInt(20) - 10); // 1e-10 .. 1e9
      return sign * mag * r.nextDouble();
    }).limit(200_000).toArray();

    double naive = 0.0;
    KahanAccumulator kahan = new KahanAccumulator();
    BigDecimal ref = BigDecimal.ZERO;

    for (double x : xs) {
      naive += x;
      kahan.add(x);
      ref = ref.add(BigDecimal.valueOf(x));
    }

    // Reference converted back to double so we compare at double resolution.
    double reference = ref.doubleValue();

    double errNaive = Math.abs(naive - reference);
    double errKahan = Math.abs(kahan.value() - reference);

    // In rare adversarial sequences Kahan can be slightly worse, but typically it's much better.
    assertTrue(errKahan <= errNaive * 2.0,
        String.format("Kahan error (%.2e) vs naive (%.2e)", errKahan, errNaive));
  }
}
{% endhighlight %}

## Performance: what it costs

Naive summation does exactly one addition per element. Kahan summation, by comparison, does a small handful of extra operations per element — three subtractions and one extra addition, on top of the one that would otherwise have been there. That is, in the end, a small constant factor, and in the great majority of analytics pipelines I have worked on, the accuracy gain is worth far more than the marginal CPU cost.

If you do want to measure the overhead carefully, the right tool to reach for is JMH, and the comparison worth running is between four variants:

* the naive loop
* `DoubleStream.sum()`
* the Kahan loop directly
* Kahan via `DoubleStream.collect`

The relative numbers, in my experience, depend more on the surrounding pipeline and the JIT's behaviour than on the algorithm itself, but the overhead of Kahan tends to be in single-digit percent territory for typical workloads.

## When NOT to use Kahan

Kahan is genuinely useful, but it is not the right tool in every situation. There are at least three categories in which I would specifically avoid reaching for it:

* **Financial calculations.** Use `BigDecimal` for money. Kahan does not give you decimal semantics, and the kinds of rounding rules that finance and accounting actually require live in a different problem entirely.
* **Tiny datasets.** When `N` is small, the cumulative error of naive summation is usually well below any threshold that matters, and the overhead of Kahan, however small, is rarely worth carrying for the negligible benefit.
* **Hard real-time or tight latency budgets.** Profile first; the overhead is usually small but it is not zero, and in the kind of code that has a hard deadline every iteration, even a few nanoseconds per element can add up to meaningful time.

## Variants worth mentioning: Neumaier and pairwise summation

Kahan is, although a good default, not the only available compensated-summation technique. It is worth at least naming a couple of the alternatives, both because they sometimes behave better than Kahan on particular kinds of data and because anyone seriously interested in numerical accuracy will encounter them sooner or later in the literature.

Neumaier summation is a small modification of Kahan that handles a specific case more gracefully: the case in which the next addend is, in magnitude, larger than the current running sum, which is a situation Kahan can mishandle in a few corner cases.

{% highlight java %}
// Neumaier variant
public final class NeumaierAccumulator {
  private double sum;
  private double c;

  public void add(double x) {
    double t = sum + x;
    if (Math.abs(sum) >= Math.abs(x)) {
      c += (sum - t) + x;
    } else {
      c += (x - t) + sum;
    }
    sum = t;
  }

  public double value() {
    return sum + c;
  }
}
{% endhighlight %}

Pairwise summation, also known as tree reduction, takes a different approach: rather than tracking compensation explicitly, it reduces error growth by combining numbers of similar magnitude together, so that the running sum never gets too far ahead of the values still being added. Some stream implementations may, behind the scenes, do something resembling this internally; the principal advantage of writing your own is that the behaviour is then explicit, reviewable, and not subject to silent change between JDK versions.

## When to use what

Pulling all of the above together, the general guidance I would offer is roughly this. Use `BigDecimal` when you need decimal semantics, and you mean it; use naive summation when `N` is small, the magnitudes of the addends are similar, and you genuinely do not care about a few low-order bits; and use Kahan or Neumaier when:

* `N` is large (thousands to millions of values)
* values span many orders of magnitude
* small contributions matter
* you want better accuracy without dragging BigDecimal everywhere   

### A note on BigDecimal vs Kahan (so we don't mix the tools)

It is worth being explicit about this distinction, because I have seen it confused often enough that the confusion is, by itself, a recurring source of bugs. **`BigDecimal` is about decimal *semantics*** — money, accounting, "pennies must add up," explicit rounding rules — and **Kahan is about *accumulation error* in `double`** when `double` is genuinely the right representation for the values being summed (metrics, measurements, statistics, ML features, telemetry) but naive summation is bleeding low-order bits over a long enough reduction.

The practical rule of thumb is straightforward enough:

- If your requirements mention **cents, statements, taxes, interest, regulatory accuracy, or mandated rounding policies** → use **BigDecimal** (and decide scale + rounding mode explicitly).   
- If your requirements mention **large aggregates, mixed magnitudes, order sensitivity, or "why did parallel give a different total?"** → keep **double**, but upgrade the summation (**Kahan / Neumaier / pairwise**), and be explicit about ordering if determinism matters.    

One small but persistent footgun while we are on the subject: `BigDecimal` only stays "decimal-correct" if you construct it correctly. Prefer parsing from a decimal string, or `BigDecimal.valueOf(double)`, over `new BigDecimal(double)`, which faithfully captures the binary representation of the double — including, of course, all of its decimal infidelity.

## Closing

Floating point, on its own terms, is not really broken; it is simply finite. The problem is not that rounding happens — rounding is what makes finite-precision arithmetic possible in the first place — but that rounding can happen many millions of times across a single reduction, while the running total continues to grow, and the cumulative effect of all those small dropped bits can become large enough to be wrong in ways that matter.

What Kahan summation does, in the end, is to keep a small ledger of what rounding has thrown away and to fold those discarded bits back into the next addition, so that the long-run drift stays bounded rather than accumulating without limit. The code change involved is genuinely small; the conceptual shift, however — from treating summation as a single line of code to treating it as a deliberate numerical algorithm — is the part that, I think, is worth taking seriously the next time you find yourself reaching for `.sum()` over a few million doubles.

---

## References

* W. Kahan, "Pracniques: Further remarks on reducing truncation errors," Communications of the ACM, 8(1), Jan. 1965.
DOI (ACM Digital Library): https://dl.acm.org/doi/10.1145/363707.363723

Open PDF (hosted copy): https://convexoptimization.com/TOOLS/Kahan.pdf

Metadata entry (Semantic Scholar): https://www.semanticscholar.org/paper/Pracniques%3A-further-remarks-on-reducing-truncation-Kahan/672a99813f52aed720d3508d6be7db461328b064

* Prof Kahan's Assorted Notes, https://people.eecs.berkeley.edu/~wkahan/
 
* N. J. Higham, "The Accuracy of Floating Point Summation", SIAM Journal on Scientific Computing (1993). https://doi.org/10.1137/0914050

* DoubleStream.sum(): https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/stream/DoubleStream.html#sum()
 
* DoubleSummaryStatistics: https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/DoubleSummaryStatistics.html
