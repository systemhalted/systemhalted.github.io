---
layout: post
title: "Part 7: Kahan Summation -- A Better sum() for Java Streams"
date: 2026-01-11
type: post
published: true
comments: true
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

In [Part 6](https://systemhalted.in/2026/01/05/defending-against-nan-without-defensive-programming-hell/), we learned to defend against NaN by validating at boundaries. Now we tackle a different kind of quiet failure: when your sum is correct at every step but still wrong at the end.
---

Your sum is lying.

Not maliciously. Not even dramatically. Just politely.

Floating point is like a tidy accountant with limited paper. Every addition gets written down with a fixed number of significant digits, rounded neatly, and the scraps are swept off the desk.

Most of the time the scraps do not matter.

Until they do.

This post is the full story of **Kahan summation**: a small trick with a big impact. It does not make floating point exact. It *does* stop your totals from quietly losing meaningful contributions when you add lots of numbers.

## The crime scene: the innocent-looking loop

Classic numerical analysis textbooks (here in Fortran, the lingua franca of 1960s numerics) love this tiny loop because it looks harmless and then betrays you.

{% highlight fortran %}
S = 0.0
DO 4 I = 1, N
  YI = ...
4 S = S + YI
{% endhighlight %}

That last line is the whole drama: `S = S + YI`.

People then drop a line like this:

> Rounding or truncation in the addition can contribute to a loss of almost log10(N) significant decimal digits in S.

That `log10(N)` sounds like wizardry.

It is not.

It is just fixed precision colliding with a growing running total.

## Why you can lose about log10(N) digits

Assume base-10 floating point with **p significant decimal digits**. (IEEE 754 is base 2, but the intuition transfers cleanly.)

Assume the `YI` values are roughly the same size and mostly the same sign, so the sum grows instead of canceling. Let a typical magnitude be `|Y|`.

After `N` terms, the true sum is roughly:

$$
S_{\text{true}} \approx N \cdot Y
$$

Now the key floating point constraint: a `p` digit floating number around magnitude `|S|` cannot represent arbitrarily tiny changes. Near `S`, the spacing between representable values is about:

$$
\Delta S \approx |S| \cdot 10^{-p}
$$

Think of `ΔS` as the width of the grid lines at the altitude where `S` lives.

When you do `S = S + YI`, the result is rounded back to `p` digits. Any increment much smaller than `ΔS` can vanish.

At the end, `|S| \approx N|Y|`, so the grid spacing near the final sum is:

$$
\Delta S \approx (N|Y|)\,10^{-p}
$$

Compare the grid spacing to the size of a typical addend:

$$
\frac{\Delta S}{|Y|} \approx N \cdot 10^{-p} = 10^{\log_{10}N - p}
$$

That ratio is the punchline.

Multiplying by `N` shifts magnitudes by `log10(N)` decimal digits. So as the running sum grows by a factor of `N`, the rounding grid spacing grows by the same factor. Relative to the scale of the things you are adding, you effectively lose about `log10(N)` digits.

Another way to say it:

$$
\text{useful digits left at the addend scale} \approx p - \log_{10}N
$$

### A concrete gut punch

Suppose you have about `p = 7` significant decimal digits (single-ish precision). Sum `N = 10^6` numbers of size about 1.

`log10(10^6) = 6`

So you can be left with roughly:

`7 - 6 = 1` meaningful decimal digit at the scale of 1

By the time `S` reaches around one million, the grid spacing near `S` is roughly:

`10^6 * 10^(-7) = 10^(-1) = 0.1`

So adding `0.01` can literally do nothing. It gets rounded away.

This is the core problem: not rounding once, but rounding *a million times* while the running total keeps inflating.

## A quick demo: sums that look reasonable and are still wrong

Here is a classic cancellation trap:

{% highlight java %}
double x = 1e16;
double naive = (x + 1.0) + 1.0 - x;   // commonly prints 0.0
System.out.println(naive);
{% endhighlight %}

The two `+ 1.0` additions happen while the running value is around `1e16`. At that scale, `1.0` can be smaller than the spacing between representable doubles, so it falls through the cracks.

If your system does analytics, pricing, telemetry, risk, recommendations, ranking, or anything where `N` gets large, this is not a cute corner case. It is the default failure mode hiding inside an innocent reduction.

## Kahan summation: sweeping the crumbs back into the pile

Kahan summation is **compensated summation**.

It keeps two numbers:

* `sum`: the running total
* `c`: a compensation term that tracks what rounding threw away last time

The mental model:

`sum` is the big obvious pile.

`c` is the tiny IOU note: the bits that tried to join the party and got turned away at the door.

### The algorithm

Given a new addend `x`:

1. Adjust the addend by what we lost previously
2. Add it
3. Update the compensation by estimating what got lost this time

{% highlight text %}
y = x - c
t = sum + y
c = (t - sum) - y
sum = t
{% endhighlight %}

That is the entire trick.

It does not change the floating point rules. It changes your strategy so the rules hurt you less.

## Java implementation: a small accumulator with big consequences

### The accumulator type

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

A note worth stating clearly:

Kahan improves accuracy a lot, but **floating point addition is still not associative**, so parallel reductions can still differ run to run because order differs. Kahan makes the wobble smaller, not impossible.

## Using it with Streams

### Option A: DoubleStream.collect (best for primitive streams)

`DoubleStream` has its own collect overload that avoids boxing.

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

Usage:

{% highlight java %}
double s1 = Kahan.sum(DoubleStream.of(0.1, 0.2, 0.3));
double s2 = Kahan.sum(myDoubleStream.parallel()); // allowed, order still not fixed
{% endhighlight %}

### Option B: a Collector (nice ergonomics for boxed streams)

This is convenient when you already have a `Stream<Double>`.

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

Usage:

{% highlight java %}
double s = myStreamOfDoubles.collect(KahanCollectors.kahanSummingDouble());
{% endhighlight %}

## Correctness: what to test, and what not to promise

### What you should promise

* Better accuracy than naive summation for large `N` and wide dynamic ranges
* Explicit behavior you control and can review in code

### What you should not promise

* Bit for bit deterministic results in parallel streams
* Exactness for money or decimal accounting

### JUnit test idea: compare against a higher-precision reference

BigDecimal is not a perfect oracle for binary floating point, but it is a very useful reference when you want to see whether one summation strategy is drifting more than another.

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

Naive sum does one add per element.

Kahan does a few extra operations per element. That is a small constant factor. In many analytics pipelines the accuracy gain is worth far more than the extra CPU.

If you want to measure overhead, use JMH and compare:

* naive loop
* `DoubleStream.sum()`
* Kahan loop
* Kahan via `DoubleStream.collect`

## When NOT to use Kahan

* Financial calculations: use BigDecimal for money. Period. Kahan does not give you decimal semantics.
* Tiny datasets: if `N` is small, the overhead is rarely worth it.
* Hard real time, tight latency budgets: profile first.

## Variants worth mentioning: Neumaier and pairwise summation

Kahan is great. It is not the only move.

Neumaier summation is a small tweak that can behave better when the next addend is larger than the running sum.

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

Pairwise summation (tree reduction) reduces error growth by summing numbers of similar magnitude together. Some stream implementations may do something like this internally, but the key benefit of writing your own is that you make the behavior explicit and reviewable.

## When to use what

Use BigDecimal when you need decimal semantics and you mean it.

Use naive summation when `N` is small, magnitudes are similar, and you truly do not care.

Use Kahan (or Neumaier) when:

* `N` is large (thousands to millions of values)
* values span many orders of magnitude
* small contributions matter
* you want better accuracy without dragging BigDecimal everywhere

## Closing

Floating point is not broken. It is finite.

The tragedy is not that rounding happens.

The tragedy is when rounding happens quietly and repeatedly and nobody is keeping score.

Kahan summation is you keeping score.

A small second variable, standing in the corner with a clipboard, refusing to let the crumbs vanish without a fight.

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