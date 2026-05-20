---
layout: post
title: 'Part 8: Big Decimal Rounding Modes - Why HALF_UP Isn''t Always the Answer'
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
comments: true
featured_image: /assets/images/featured/2026-02-05-rounding-modes-half-up-isnt-always-the-answer.png
featured_image_alt: 'Abstract illustration of rounding in Java: decimal numbers float above a dial labeled HALF_UP and HALF_EVEN, with arrows showing tie-breaking directions and a subtle bias toward HALF_UP.'
featured_image_caption: 'Rounding is policy in disguise: HALF_UP always nudges ties the same way, while HALF_EVEN spreads the bias out.'
description: Learn why HALF_UP rounding isn't always correct and how to choose a rounding policy in Java (HALF_EVEN, HALF_UP, HALF_DOWN, UP, DOWN, CEILING, FLOOR, UNNECESSARY).
slug: rounding-modes-why-half-up-isnt-always-the-answer
---

*This post is part of my [Floating Point Without Tears](https://systemhalted.in/categories/#cat-series-4-floating-point-without-tears) series on how Java numbers misbehave and how to live with them.*

In [Part 7](https://systemhalted.in/2026/01/11/kahan-summation-java-streams/) of this series, we looked at summation error and how Kahan compensation can keep a long reduction from quietly losing low-order bits. This post is about a different and, in some ways, more consequential precision trap: the moment at which a value is rounded down to fewer digits in order to be displayed, stored, or reported.

Rounding looks like a small detail in the code, and it almost never is one. It is the place where many otherwise-correct calculations end up disagreeing with audits, ledgers, and reconciliations, often in ways that are difficult to diagnose because the disagreement only appears at scale. Most teams I have seen pick a rounding mode in roughly the same way that most people pick a film on a streaming service — by going with whichever option happened to be already playing — and in Java, the option that happens to be already playing is very often `HALF_UP`, on the implicit assumption that this is "normal" rounding.

> "We'll use `HALF_UP`. That's normal rounding. Done."

Then a pricing engine ships, or a statement generator, or a ledger, or a tax calculator, or an amortization schedule — and at some point afterwards it becomes apparent that **rounding is policy**, not arithmetic. Or, more precisely, it is arithmetic with consequences, and the choice of which rounding mode to apply turns out to be a product decision wearing mathematical clothing. This post is about how to make that choice deliberately, and about why `HALF_UP` is not the universal solvent it is so often assumed to be.

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

The drama in rounding, almost without exception, is not really about choosing between `2.341` and `2.34`. It is about *ties* — values that lie exactly halfway between two representable steps at the precision you are rounding to.

At two decimal places, the troublesome values are the ones that look like this:

- `1.005`
- `2.675`
- `10.125`

It is worth being precise about what counts as a tie, because the term is sometimes applied loosely to values that are not, strictly speaking, halfway between anything. A value is a tie at a given scale only when the first discarded digit is exactly `5` and all subsequent discarded digits are exactly `0`. So `1.005` is a tie at two decimal places, and so is `1.00500…`, but `1.0051` is not a tie — it is, on inspection, closer to `1.01` than to `1.00`, and any reasonable rounding mode will produce `1.01` regardless of how it handles ties.

The reason ties matter so much in practice is that, depending on which way the rounding mode resolves them, the cumulative effect across many operations can be quite different. If you consistently push ties in one direction — say, always upward — you introduce a systematic bias into every aggregate that depends on those rounded values. Sometimes that bias is exactly what the domain wants (retail prices, for instance, often round in a particular direction by convention); often it is not, occasionally it is actually prohibited by regulation or contract, and even when it is none of those things, it is the kind of pattern that tends to make reconciliation teams unhappy when the totals begin to drift.

## Java's rounding toolbox {#toolbox}

Java's standard library, in `java.math.RoundingMode`, exposes a fairly complete set of rounding policies. The interesting question, in the end, is rarely which of them is "available" — they all are — but rather which of them matches the contract the domain actually wants enforced. The available modes are:

- `HALF_UP` - round to nearest; if exactly halfway, round away from zero (1.5 -> 2, -1.5 -> -2)
- `HALF_DOWN` - round to nearest; if exactly halfway, round toward zero (1.5 -> 1, -1.5 -> -1)
- `HALF_EVEN` - round to nearest; if exactly halfway, round to the result whose last kept digit is even (banker's rounding, also called round-half-to-even)
- `UP` - always away from zero
- `DOWN` - always toward zero (truncate)
- `CEILING` - toward positive infinity (-1.231 -> -1.23, 1.231 -> 1.24 at 2dp)
- `FLOOR` - toward negative infinity (-1.231 -> -1.24, 1.231 -> 1.23 at 2dp)
- `UNNECESSARY` - throw if rounding would be required (which I have come to think of as a "make bugs loud" mode)

It is also worth recalling that calling `setScale(...)` without specifying a rounding mode will, if rounding turns out to be required, throw — which is a sensible default but is occasionally surprising:

{% highlight java %}
new BigDecimal("1.234").setScale(2); // throws ArithmeticException
{% endhighlight %}

And the most important practical rule, which I find myself repeating in code review more often than any other rule in this area:

**If you care about exact decimal policy, avoid rounding a `double`. Round a `BigDecimal` created from a string (or from an exact integer scale).**

### The classic trap: `new BigDecimal(double)` {#classic-trap}

This is the trap that catches almost everyone at least once, and it is worth showing in code rather than just describing in prose:

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

The expectation, of course, is that both values round to `1.01`. What actually happens is that the first one rounds to `1.00`, because `1.005` as a binary floating-point value is not, in fact, exactly `1.005` — it is a hair less than that, by exactly the small amount that binary floating point cannot quite represent the decimal fraction `0.005`. When you then ask `BigDecimal` to round that approximate value, it dutifully rounds the value it actually has, which falls just below the tie boundary.

If you find yourself, in a finance system, looking at a result in which `1.005` appears to round to `1.00` under `HALF_UP`, the right interpretation is not that Java is being eccentric. The right interpretation is that you have fed an approximate binary representation into an exact decimal rounding routine, and that the routine has, accurately and unhelpfully, given you the answer that corresponds to the value it was actually given.

### What about `BigDecimal.valueOf()`? {#valueof}

There is a third constructor in this space which sits between the two previous options and which readers trip over often enough that it is worth treating explicitly: `BigDecimal.valueOf(double)`.

{% highlight java %}
BigDecimal a = new BigDecimal(1.005);        // Dangerous: uses exact binary representation
BigDecimal b = BigDecimal.valueOf(1.005);    // Safer: uses Double.toString() internally
BigDecimal c = new BigDecimal("1.005");      // Safest: exact decimal from string
{% endhighlight %}

`BigDecimal.valueOf(double)` will, in most everyday cases, behave as if you had used the string constructor, because it routes the conversion through `Double.toString()` internally — and `Double.toString` is specified to return the shortest decimal representation that round-trips back to the same double. So when you start from a literal like `1.005`, `valueOf` gives you the decimal `1.005` rather than the binary-exact value, which is what most callers actually wanted.

A reasonable rule of thumb, based on which entry point one is using:

- Use `new BigDecimal("...")` for literals and external decimal inputs that arrive as strings
- Use `BigDecimal.valueOf(double)` only when you already have a double in hand and need the best possible decimal view of it (still risky after computations, but better than `new BigDecimal(double)`)
- Never use `new BigDecimal(double)` unless you explicitly want the exact binary-to-decimal conversion, which is rarely what callers expect

It is worth one further caution. If the double you are wrapping has come out of arithmetic — rather than out of a literal — then the value you are now "viewing" through `valueOf` may already be quite far from the decimal you think you started with. `valueOf` is an honest decimal view of whatever double it receives; it is not a cleansing ritual that retroactively repairs precision lost earlier in the calculation.

## Why HALF_UP can be the wrong default {#half-up-bias}

`HALF_UP` is, in fairness, intuitive. It matches what most of us were taught with a pencil and paper in school, and it has the agreeable property of making the answer easy to predict in any individual case. The trouble is that, when applied repeatedly to many values, it can introduce a systematic **drift**, because every tie is resolved in the same direction.

It is worth pausing for a moment on a small irony of the IEEE 754 standard here. IEEE 754's default rounding mode for binary floating-point arithmetic is *round to nearest, ties to even* — which is, in effect, `HALF_EVEN`. Each individual `double` operation in Java is specified to behave as if its result had been rounded that way. The mild irony, then, is that when developers reach for `BigDecimal` precisely because they are now worried about decimal correctness, many of them then choose `HALF_UP`, thereby reintroducing the very bias that IEEE 754 had originally been designed to avoid.

### Bias demo: HALF_UP vs HALF_EVEN {#bias-demo}

Suppose, in order to make this concrete, that you have a population of values which all happen to land exactly on ties at two decimal places. (This kind of thing happens more often than people tend to expect, particularly after divisions and intermediate scaling steps.) The behaviour of the two main candidate rounding modes, side by side, looks like this:

- `HALF_UP`: `1.005 -> 1.01`, `1.015 -> 1.02`, `1.025 -> 1.03` ... always nudging up
- `HALF_EVEN`: `1.005 -> 1.00`, `1.015 -> 1.02`, `1.025 -> 1.02` ... nudging toward whichever side has an even last digit, and so alternating which side "wins" on ties

The structural difference is that `HALF_EVEN` alternates which direction it pushes ties, while `HALF_UP` always pushes them the same way. This is the underlying reason why **banking and accounting systems often prefer `HALF_EVEN`**: across a large enough population of values, the alternation cancels out into something close to zero net bias, while `HALF_UP` accumulates a small but consistent upward drift that becomes visible at scale.

### The bias in action {#bias-action}

A short program makes the difference clearer than any description does:

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

And the resulting output:

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

Across these ten values, the difference between `HALF_UP` and the true sum is five cents. That is, on its own, an unimpressive amount of money. The point of the demonstration, however, is that the same bias scales linearly: across millions of transactions of this kind, the same five-cents-per-ten pattern can become a meaningful, persistent, and entirely systematic drift in favour of one party.

### How HALF_UP can favor one party at scale {#pennies-from-heaven}

When this kind of pattern shows up in a system that processes millions of transactions in which ties are common, what `HALF_UP` does, in effect, is to consistently favour whichever side of the transaction benefits from rounding upward. If you happen to be that party, you may, over time, find that your books "win" fractions of a cent more often than they "lose"; and that is, generally, fine — until regulators, auditors, or customers do their own arithmetic and notice the same pattern from the other side.

Which is to say, the question worth asking is not really "which rounding mode is mathematically correct?", because none of them is uniquely correct in any abstract sense. The right question, as it almost always is in this kind of design choice, is:

**Which rounding policy matches the domain contract?**

## Rounding is not only *mode*. It's also *when*. {#rounding-timing}

There is a second axis to this kind of decision, which gets less attention than it deserves but which often matters at least as much as the choice of mode itself. The axis is *when* in a calculation rounding actually happens. Two broad designs are common in production code:

1. Round at every step (easy, often wrong)
2. Keep high precision internally, round only at boundaries (harder, usually right)

### Example: line items and invoices {#invoices}

To make the trade-off concrete, consider a fairly standard invoicing setup:

- Price per item carries four decimal places of precision
- The currency, for display and settlement, is two decimals
- Taxes are computed on totals rather than per-line-item (which is the more common convention)

If rounding happens too early in this kind of calculation, the invoice total can end up disagreeing with what the underlying ledger says it ought to be. The four candidate policies, in this small space, are:

- Round each line item to two decimals, then sum the rounded values
- Sum the unrounded line items at full precision, then round once at the total
- Compute tax per line item and then sum the taxes
- Compute tax once on the total, then round the tax once

All four of these are, in some sense, "reasonable", and none of them is wrong in the abstract. Only one of them, however, will actually agree with the rules your business has adopted, and the only way to make sure you have picked the right one is to choose explicitly, document the choice somewhere where it can be referred to later, and write tests that pin the chosen behaviour in place.

## A practical Java pattern: Money as scaled integer {#money-pattern}

For currency in particular, the simplest representation that is also genuinely correct in most cases is, in my experience, to store amounts as integer minor units — long-typed cents, in the case of a US-style currency — to do all of the internal arithmetic in integers, and to convert back to a decimal representation only at the boundaries where the value is being displayed or transmitted. This pattern avoids a great deal of `BigDecimal` overhead, and it eliminates the entire class of bug that arises from rounding the same value twice in slightly different ways during a calculation.

### Simple Money type (cents) {#money-type}

A reasonable starting point looks something like this:

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

The pattern at work in this small class is, I think, worth pulling out explicitly. Inputs are parsed from strings rather than from doubles; the scaling is always explicit; the rounding mode is a parameter at any point that policy has to be applied; and the internal representation is integer cents rather than `BigDecimal`. The code is a little longer than the obvious naive version would have been, but each of those choices removes a class of bug rather than papering over one.

There is one design choice in `ofDollars` worth calling out explicitly: it silently rounds inputs like `"10.129"` to `"10.13"`. That is sometimes exactly what is wanted — for display amounts, for instance, where the upstream code has already validated the value — but for payments and ledgers it is often safer to use `ofDollarsStrict` instead, which simply rejects any input that is not already at exactly two decimals. The strict version forces validation to happen at the point where the value enters the system, rather than letting an off-scale value drift in and quietly become representable.

For multi-currency systems, the natural extension is to add a `Currency` field to the type and to ensure that arithmetic across different currencies is rejected outright. The core pattern, however, stays the same: integer minor units internally, with rounding occurring only at clearly identified boundaries.

## Quick guide: what each rounding mode is "for" {#field-guide}

The following is a field guide rather than a strict ruleset; the right answer in any given system is always whichever mode matches the domain contract, but these are the rough shapes of cases I have run into often enough to recommend by default.

### Use HALF_EVEN when... {#use-half-even}

You are aggregating a large number of rounded values and you want to minimise systematic bias in the aggregate. This is the right default for most accounting ledgers, for interest accrual across many accounts, and for any large-scale reporting in which the total over many ties is what matters more than the result of any individual rounding step.

### Use HALF_UP when... {#use-half-up}

The domain explicitly expects "schoolbook" rounding — the kind of rounding most people learned in primary school, where 0.5 always rounds up. This is appropriate for retail display prices, for some tax jurisdictions in which the rule is set by statute, and for human-facing calculations where the convention is part of the user experience and surprising the user with banker's rounding would, on balance, do more harm than the bias it would prevent.

### Use DOWN when... {#use-down}

Truncation is explicitly what the policy requires — typically in fee calculations or in conservative estimates where the rule is something like "we may not exceed this cap under any circumstances," and where rounding in the more usual direction could produce an out-of-bounds value.

### Use CEILING or FLOOR when... {#use-ceiling-floor}

These differ from `UP` and `DOWN` in that the direction is interpreted relative to the number line, rather than relative to zero, which makes them the right choice when sign matters:

- `CEILING` is "toward positive infinity" (-1.231 -> -1.23, 1.231 -> 1.24 at 2dp)
- `FLOOR` is "toward negative infinity" (-1.231 -> -1.24, 1.231 -> 1.23 at 2dp)

These tend to be the right choice for constraints, limits, and compliance rules of the form "must be at least X" or "must be at most Y".

### Use UNNECESSARY when... {#use-unnecessary}

You want the program to fail loudly the instant it encounters a value that you did not expect to need rounding. This sounds, when written down, like an irritation; in my experience it is, in fact, an enormously useful debugging and validation aid:

{% highlight java %}
BigDecimal subtotal = new BigDecimal("12.34");
BigDecimal rate = new BigDecimal("0.075");
BigDecimal tax = subtotal.multiply(rate);

// Fail fast if tax isn't exactly representable at 2 decimals as required by policy
tax = tax.setScale(2, RoundingMode.UNNECESSARY);
{% endhighlight %}

The exception thrown by `UNNECESSARY` is not, in this kind of usage, a nuisance to be caught and ignored. It is a spotlight that the runtime is shining on an assumption you had forgotten you were making, and being told about that assumption explicitly is almost always more useful than letting it quietly produce a slightly wrong answer further downstream.

## The moral of the story {#moral}

`HALF_UP`, in summary, is not really wrong; it is simply not universal. Rounding modes, taken together, are not "implementation details" of any kind. They are product decisions, made of policy rather than mathematics, and they need to be picked the way that any other policy is picked — explicitly, with tests, and with a paper trail that lets future readers understand why a particular choice was made and what would have to change for the choice to be revisited.

## TL;DR {#tldr}

- Ties (first discarded digit is 5, rest are zeros) are where rounding policy matters most.
- `HALF_UP` is intuitive but can introduce bias at scale.
- `HALF_EVEN` often reduces bias for aggregates.
- Avoid rounding `double` values when policy matters. Use `BigDecimal` created from strings or scaled integers.
- Prefer `BigDecimal.valueOf(double)` over `new BigDecimal(double)` when you must start from a double - but remember it's not a cleansing ritual.
- Decide *when* you round, not just *how* you round.
- Prefer rounding once at boundaries, not repeatedly in the middle.
- Use `UNNECESSARY` to catch "we assumed this would be exact" bugs early.
