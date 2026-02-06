---
layout: post
title: "Part 8: Rounding Modes - Why HALF_UP Isn't Always the Answer"
type: post
published: true
comments: true
slug: rounding-modes-why-half-up-isnt-always-the-answer
categories:
  - Computer Science
  - Software Engineering
  - Technology
  - Series 4 - Floating Point Without Tears
tags:
  - java
  - floating-point
  - bigdecimal
  - rounding
  - finance
  - numerics
description: "Learn why HALF_UP rounding isn't always correct and how to choose a rounding policy in Java (HALF_EVEN, HALF_UP, HALF_DOWN, UP, DOWN, CEILING, FLOOR, UNNECESSARY)."
---

*This post is part of my [Floating Point Without Tears](https://systemhalted.in/categories/#cat-series-4-floating-point-without-tears) series on how Java numbers misbehave and how to live with them.*

In [Part 7](https://systemhalted.in/2026/01/11/kahan-summation-java-streams/), we tackled summation error with Kahan compensation. Now we zoom in on a different precision trap: the moment you round a value to fewer digits.

Rounding is one of those "small" problems that quietly eats your lunch, your audit trail, and your sleep.

Most teams pick a rounding mode the way people pick a Netflix show: whatever was already playing. 

In Java, that default story often becomes:

> "We'll use `HALF_UP`. That's normal rounding. Done."

And then you ship a pricing engine, a statement generator, a ledger, a tax calculator, or an amortization schedule...

...and then you discover that **rounding is policy**, not maths. Fine. It’s maths. But it’s maths with consequences.

This post is about **choosing rounding modes intentionally**, and why `HALF_UP` is not the universal solvent people think it is.

## Quick Reference: Rounding Mode Cheat Sheet {#cheat-sheet}

| Mode | Behavior | When | Jump |
|------|----------|------|------|
| `HALF_EVEN` | Ties -> nearest even digit | Aggregates, reducing bias | [↓](#use-half-even) |
| `HALF_UP` | Ties -> away from zero | Schoolbook rounding, retail | [↓](#use-half-up) |
| `HALF_DOWN` | Ties -> toward zero | Policy requires ties toward zero (rare; document it) | [↓](#toolbox) |
| `UP` | Always away from zero | Conservative bounds (never underestimate magnitude) | [↓](#toolbox) |
| `DOWN` | Always toward zero | Fee caps, conservative limits | [↓](#use-down) |
| `CEILING` | Toward +∞ (1.231 -> 1.24, -1.231 -> -1.23) | "At least" constraints | [↓](#use-ceiling-floor) |
| `FLOOR` | Toward -∞ (1.231 -> 1.23, -1.231 -> -1.24) | "At most" constraints | [↓](#use-ceiling-floor) |
| `UNNECESSARY` | Throw if rounding needed | Validation, catching assumptions | [↓](#use-unnecessary) |

**Key rules:**
- Avoid rounding double when policy matters: use BigDecimal from strings → [The Classic Trap](#classic-trap)
- Decide *when* to round, not just *how* → [Rounding Timing](#rounding-timing)
- For money, use scaled integers internally → [Money Pattern](#money-pattern)

---

## The real problem: ties (the 5s) {#ties}

Most rounding drama is not about 2.341 vs 2.34. It's about *ties*: values exactly halfway between representable steps.

At 2 decimal places, these are the spicy ones:

- `1.005`
- `2.675`
- `10.125`

It's a tie only when the first discarded digit is 5 and all following discarded digits are 0, for the scale you're rounding to (e.g., `1.005` or `1.00500...` when rounding to 2 decimals).

A value like `1.0051` is not a tie - it's closer to `1.01`.

If you always push ties upward, you introduce a systematic bias. Sometimes that bias is desired. Often it's not. Sometimes it's illegal. Sometimes it's fine but your reconciliation team will develop a new religion and curse your name in it.

## Java's rounding toolbox {#toolbox}

Here is what Java offers. The real work is choosing a policy that matches your domain contract. Java gives you `java.math.RoundingMode`:

- `HALF_UP` - round to nearest; if exactly halfway, round away from zero (1.5 -> 2, -1.5 -> -2)
- `HALF_DOWN` - round to nearest; if exactly halfway, round toward zero (1.5 -> 1, -1.5 -> -1)
- `HALF_EVEN` - round to nearest; if exactly halfway, round to the result whose last kept digit is even (banker's rounding, also called round-half-to-even)
- `UP` - always away from zero
- `DOWN` - always toward zero (truncate)
- `CEILING` - toward positive infinity (-1.231 -> -1.23, 1.231 -> 1.24 at 2dp)
- `FLOOR` - toward negative infinity (-1.231 -> -1.24, 1.231 -> 1.23 at 2dp)
- `UNNECESSARY` - throw if rounding would be required (my favorite "make bugs loud" mode)

Also remember: `setScale(...)` without a rounding mode throws if rounding is required.

{% highlight java %}
new BigDecimal("1.234").setScale(2); // throws ArithmeticException
{% endhighlight %}

And the most important practical rule:

**If you care about exact decimal policy, avoid rounding a `double`. Round a `BigDecimal` created from a string (or exact integer scale).**

### The classic trap: `new BigDecimal(double)` {#classic-trap}

{% highlight java %}
import java.math.BigDecimal;
import java.math.RoundingMode;

public class RoundingTrap {
  public static void main(String[] args) {
    BigDecimal a = new BigDecimal(1.005);               // from double
    BigDecimal b = new BigDecimal("1.005");             // from string

    System.out.println(a.setScale(2, RoundingMode.HALF_UP)); // 1.00
    System.out.println(b.setScale(2, RoundingMode.HALF_UP)); // 1.01
  }
}
{% endhighlight %}

What you *expect*: both become `1.01`

What often happens: the first becomes `1.00` because `1.005` as a binary floating value is actually a hair under 1.005.

If you're in finance and you see "1.005 rounds to 1.00", that's not "Java being weird". That's **you feeding approximate binary into exact decimal rounding** and being surprised it behaves like... approximation.

### What about `BigDecimal.valueOf()`? {#valueof}

There's a middle ground that readers constantly trip over: `BigDecimal.valueOf(double)`.

{% highlight java %}
BigDecimal a = new BigDecimal(1.005);        // Dangerous: uses exact binary representation
BigDecimal b = BigDecimal.valueOf(1.005);    // Safer: uses Double.toString() internally
BigDecimal c = new BigDecimal("1.005");      // Safest: exact decimal from string
{% endhighlight %}

`BigDecimal.valueOf(double)` often behaves like the string constructor because it uses `Double.toString()` internally, which gives you the shortest decimal representation that round-trips correctly.

The rule of thumb:
- Use `new BigDecimal("...")` for literals and external decimal inputs
- Use `BigDecimal.valueOf(double)` only when you already have a double and need the best possible decimal view of it (still risky after computations, but better than `new BigDecimal(double)`)
- Never use `new BigDecimal(double)` unless you explicitly want the exact binary-to-decimal conversion

One caution: if the double came from arithmetic, the value you're "viewing" may already be far from the decimal you think you had. `valueOf` is not a magical cleansing ritual.

## Why HALF_UP can be the wrong default {#half-up-bias}

`HALF_UP` is intuitive. It matches what humans do with pencil maths. But for repeated operations, it can create **drift** because ties always go one way.

**IEEE 754 connection**: IEEE 754's default rounding mode is "round to nearest, ties to even" - essentially `HALF_EVEN`. Java `double` results are specified to behave as if rounded that way for each operation. The irony is that when you switch to `BigDecimal` for precision, many developers then pick `HALF_UP`, introducing the very bias that IEEE 754 was designed to avoid.

### Bias demo: HALF_UP vs HALF_EVEN {#bias-demo}

Let's imagine you have many values that land exactly on ties at 2 decimals (it happens more than people think, especially after division and intermediate scaling).

Here's the "policy difference" in one glance:

- `HALF_UP`: `1.005 -> 1.01`, `1.015 -> 1.02`, `1.025 -> 1.03` ... always nudging up
- `HALF_EVEN`: `1.005 -> 1.00`, `1.015 -> 1.02`, `1.025 -> 1.02` ... nudging toward even to cancel bias over time

Notice how HALF_EVEN alternates which side ‘wins’ on ties; HALF_UP always pushes the same direction. This is why **banking and accounting systems often prefer `HALF_EVEN`**: it reduces systematic rounding bias across large aggregates.

### The bias in action {#bias-action}

{% highlight java %}
import java.math.BigDecimal;
import java.math.RoundingMode;

public class BiasDemonstration {
  public static void main(String[] args) {
    String[] ties = {"1.005", "1.015", "1.025", "1.035", "1.045",
                     "1.055", "1.065", "1.075", "1.085", "1.095"};
    
    BigDecimal sumHalfUp = BigDecimal.ZERO;
    BigDecimal sumHalfEven = BigDecimal.ZERO;
    BigDecimal trueSum = BigDecimal.ZERO;
    
    System.out.println("Value   -> HALF_UP / HALF_EVEN");
    for (String tie : ties) {
      BigDecimal bd = new BigDecimal(tie);
      BigDecimal roundedUp = bd.setScale(2, RoundingMode.HALF_UP);
      BigDecimal roundedEven = bd.setScale(2, RoundingMode.HALF_EVEN);
      
      System.out.println(tie + " -> " + roundedUp + " / " + roundedEven);
      
      sumHalfUp = sumHalfUp.add(roundedUp);
      sumHalfEven = sumHalfEven.add(roundedEven);
      trueSum = trueSum.add(bd);
    }
    
    System.out.println();
    System.out.println("HALF_UP sum:   " + sumHalfUp);
    System.out.println("HALF_EVEN sum: " + sumHalfEven);
    System.out.println("True sum:      " + trueSum.setScale(2));
  }
}
{% endhighlight %}

Output:

{% highlight plaintext %}
Value   -> HALF_UP / HALF_EVEN
1.005 -> 1.01 / 1.00
1.015 -> 1.02 / 1.02
1.025 -> 1.03 / 1.02
1.035 -> 1.04 / 1.04
1.045 -> 1.05 / 1.04
1.055 -> 1.06 / 1.06
1.065 -> 1.07 / 1.06
1.075 -> 1.08 / 1.08
1.085 -> 1.09 / 1.08
1.095 -> 1.10 / 1.10

HALF_UP sum:   10.55
HALF_EVEN sum: 10.50
True sum:      10.50
{% endhighlight %}

Ten values. A nickel of drift. Scale that to millions of transactions.

### The "pennies from heaven" problem {#pennies-from-heaven}

If you process millions of transactions where ties are common, `HALF_UP` can consistently favor one party. That might mean your company "wins" fractions of a cent more often than it "loses". That sounds fun until regulators, auditors, or customers notice.

So the question isn't "which is mathematically correct?" The question is:

**Which rounding policy matches the domain contract?**

## Rounding is not only *mode*. It's also *when*. {#rounding-timing}

Two designs:

1. Round at every step (easy, often wrong)
2. Keep high precision internally, round only at boundaries (harder, usually right)

### Example: line items and invoices {#invoices}

Consider:
- Price per item has 4 decimal precision
- Currency is 2 decimals
- Taxes computed on totals, not per line (common)

If you round too early, the invoice total can differ from the expected ledger total.

Policy choices matter:
- Round each line item then sum
- Sum unrounded lines then round once
- Compute tax per line then sum tax
- Compute tax on total then round tax once

All are "reasonable". Only one matches your business rules. Pick explicitly. Document it. Test it.

## A practical Java pattern: Money as scaled integer {#money-pattern}

For currency, the simplest *correct* representation is usually:
- store money as `long` minor units (cents)
- do arithmetic in integers
- only convert for display

This avoids a lot of BigDecimal overhead and removes the "oops I rounded twice" class of bugs.

### Simple Money type (cents) {#money-type}

{% highlight java %}
import java.math.BigDecimal;
import java.math.RoundingMode;

public final class Money {
  private final long cents;

  private Money(long cents) { this.cents = cents; }

  public static Money ofDollars(String amount) {
    // Parse exact decimal dollars, then scale to cents.
    // This version rounds permissively; see ofDollarsStrict for validation.
    BigDecimal bd = new BigDecimal(amount).setScale(2, RoundingMode.HALF_EVEN);
    return new Money(bd.movePointRight(2).longValueExact());
  }

  /**
   * Strict version: reject inputs that aren't exactly 2 decimals.
   * @throws ArithmeticException if rounding would be required
   */
  public static Money ofDollarsStrict(String amount) {
    BigDecimal bd = new BigDecimal(amount).setScale(2, RoundingMode.UNNECESSARY);
    return new Money(bd.movePointRight(2).longValueExact());
  }

  public Money plus(Money other) {
    return new Money(Math.addExact(this.cents, other.cents));
  }

  /**
   * Multiply by a factor with explicit rounding policy.
   * Notice we round only at the boundary where we return to cents.
   * In production, consider taking a BigDecimal factor to avoid parsing repeatedly.
   */
  public Money times(String factor, RoundingMode mode) {
    BigDecimal bd = BigDecimal.valueOf(cents)
        .movePointLeft(2)
        .multiply(new BigDecimal(factor))
        .setScale(2, mode);
    return new Money(bd.movePointRight(2).longValueExact());
  }

  public BigDecimal toBigDecimal() {
    return BigDecimal.valueOf(cents).movePointLeft(2);
  }

  @Override
  public String toString() { return toBigDecimal().toPlainString(); }
}
{% endhighlight %}

Note the vibe:
- parse from string
- scale explicitly
- rounding mode is a parameter for "policy points"
- internal storage is integer cents

**A design choice worth calling out:** The `ofDollars` method silently rounds inputs like "10.129" to "10.13". Sometimes that's desired for display money. For payments and ledgers, `ofDollarsStrict` is often safer - it rejects inputs that aren't already at 2 decimals, forcing upstream validation.

For multi-currency systems, you'd add a `Currency` field and ensure you never mix currencies in arithmetic. But the core pattern stays the same: integers internally, rounding only at boundaries.

## Quick guide: what each rounding mode is "for" {#field-guide}

This is not law. This is a field guide.

### Use HALF_EVEN when... {#use-half-even}

You are aggregating lots of rounded values and want less bias. Accounting ledgers, interest accrual across many accounts, large-scale reporting.

### Use HALF_UP when... {#use-half-up}

The domain explicitly expects "schoolbook rounding". Retail display prices, some tax jurisdictions, human-facing calculations where policy says ".5 rounds up".

### Use DOWN when... {#use-down}

Truncation is explicitly required. Some fee calculations or conservative estimates where you must not exceed a cap.

### Use CEILING or FLOOR when... {#use-ceiling-floor}

The direction matters with sign:
- `CEILING` is "toward positive infinity" (-1.231 -> -1.23, 1.231 -> 1.24 at 2dp)
- `FLOOR` is "toward negative infinity" (-1.231 -> -1.24, 1.231 -> 1.23 at 2dp)

These are great for constraints, limits, and compliance rules.

### Use UNNECESSARY when... {#use-unnecessary}

You want your program to scream the instant it encounters a value you didn't expect to need rounding. This is amazing in intermediate validation and testing.

{% highlight java %}
BigDecimal subtotal = new BigDecimal("12.34");
BigDecimal rate = new BigDecimal("0.075");
BigDecimal tax = subtotal.multiply(rate);

// Fail fast if tax isn't exactly representable at 2 decimals as required by policy
tax = tax.setScale(2, RoundingMode.UNNECESSARY);
{% endhighlight %}

That exception is not a nuisance. It's a spotlight on an assumption you forgot you made.

## The moral of the story {#moral}

`HALF_UP` is not evil. It's just not universal.

Rounding modes are not "implementation details". They are **product decisions with maths clothing on**.

Pick them like you pick authorization rules: explicitly, testably, and with a paper trail.

## TL;DR {#tldr}

- Ties (first discarded digit is 5, rest are zeros) are where rounding policy matters most.
- `HALF_UP` is intuitive but can introduce bias at scale.
- `HALF_EVEN` often reduces bias for aggregates.
- Avoid rounding `double` values when policy matters. Use `BigDecimal` created from strings or scaled integers.
- Prefer `BigDecimal.valueOf(double)` over `new BigDecimal(double)` when you must start from a double - but remember it's not a cleansing ritual.
- Decide *when* you round, not just *how* you round.
- Prefer rounding once at boundaries, not repeatedly in the middle.
- Use `UNNECESSARY` to catch "we assumed this would be exact" bugs early.
