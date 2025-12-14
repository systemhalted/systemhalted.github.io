---
layout: post
title: Testing and the Perfect Software
category: [Software Engineering]
tags: [testing, quality, risk, tdd]
comments: true
featured: false
description: Testing matters, but choosing what to test is the real craft. A practical way to decide what must be tested, what should be tested, and what is good to have.
---

Testing is important. Testing software is important.

But testing cannot guarantee a perfect product.

At best, testing gives you information. That information helps you mitigate the risk of releasing something that is quietly wrong, and quietly expensive.

If you want a perfect product, you would need perfect and exhaustive testing. Gerald M. Weinberg points out the trap: exhaustive testing implies an infinite number of tests, and that takes more time than the life of the product itself[^1].

Edsger W. Dijkstra said, “Testing may convincingly demonstrate the presence of bugs, but can never demonstrate their absence.”[^2]

So do not treat tests like a purity ritual. Treat them like a flashlight. A very practical flashlight. One you point at the dark corners first.

## Testing is important, but knowing what to test is imperative

Most teams do not fail because they do not test.
They fail because they test the wrong things, at the wrong layer, for the wrong reasons.

The real question is not “Do we have tests?”
The real question is “Are our tests buying us truth, where it matters most?”

A simple way to choose is to think in tiers - Must Haves (Guarantees), Should Haves (Safeguards), Good to Have (Hardening)

### Must be tested (Guarantees)
These are the tests for the things that, if they break, make the business bleed, trust vanish, and regulators reach for their red pens.

Examples:
1. Money movement and irreversibility: double charges, missing payments, incorrect balances, wrong rounding.
2. Identity and authorization: user A accessing user B’s data, broken MFA, weak reset flows.
3. Data integrity invariants: dedupe rules, ordering guarantees, idempotency, “exactly once” assumptions.
4. Privacy and compliance: PII leakage, audit log gaps, retention and encryption failures.

### Should be tested (Safeguards)
These tests cover the everyday production failure modes, not glamorous, but relentlessly loyal to chaos.

Examples:
1. Integration seams: timeouts, retries, partial failures, schema changes.
2. Negative paths: invalid inputs, missing fields, weird encodings, malformed payloads.
3. Performance cliffs: cold starts, peak traffic, queue buildup, slow queries.

### Good to have (Hardening)
This is maturity. Not mandatory for day one, but it pays rent for years.

Examples:
1. Property based tests: verify invariants across many generated inputs.
2. Fuzzing: especially for parsers, inputs, and security boundaries.
3. Chaos and resilience tests: inject latency, kill dependencies, verify graceful degradation.
4. Observability checks: alerts that fire, logs that help, traces that connect.

## Your test portfolio

Think of tests like a portfolio. You are allocating limited time to buy maximum confidence.

Some tests are cheap and plentiful.
Some are fewer but high value.
Some are expensive insurance policies.

A healthy suite is not “more tests".
It is better allocation.

Two rules keep you honest:
1. Put most assertions as close to the code as possible. Fast feedback. Precise failures.
2. Put a small number of assertions as close to the user as necessary. Real confidence.

## The testing pyramid

The classic pyramid is still useful, not as dogma, but as economics.


```
End-to-End (few)
Integration / Component (some)
Unit (many)
```

Unit tests are cheap, fast, and local.

End-to-end tests are expensive, slow, and brittle, but they buy you “did the actual business journey work?”

The pyramid is not a moral statement. It is a cost statement.

### Unit tests
Best for pure and deterministic logic: calculations, transformations, validation, edge cases, invariants.

Unit tests answer: “Is this piece correct in isolation?”

A unit test is most valuable when it is **small**, **fast**, **deterministic**, and cheap enough to run on every change. Google’s testing guidance emphasizes “small tests”, their closest equivalent to unit tests as constrained in resources, and their book[^4] stresses that unit tests should be fast and deterministic so engineers can run them frequently.

Michael Feathers’ commonly cited rule of thumb is also useful as a boundary. If a test touches a database, the network, the filesystem, or needs a special environment configuration, it’s not a unit test. It's pretending to be one[^5].

A common trap is **over-mocking**. If a unit test is mostly mocks, stubs, and call verification, you may be testing your imagination instead of behavior. Prefer asserting outputs and state over asserting call choreography. Only lean on interaction-based or call-count assertions when the unit’s job is orchestration, for example retries, sequencing, or enforcing that a collaborator is invoked a specific number of times.

### Integration and component tests
These test the seams where production loves to bite.

Integration tests answer:

> Do my assumptions about the world hold?

Martin Fowler’s simplest framing is still the most useful[^6]: integration tests check whether independently developed units work correctly when connected. The term is overloaded, so it helps to state the scope you mean (two components, one service plus its database, one service plus a message broker, etc.).

Component tests are a related idea: they limit the exercised software to a *portion* of the system (a component) rather than the full stack. In practice, that often means “this service works with its dependencies, without standing up the entire ecosystem.”

Google’s “test sizes” vocabulary maps nicely here. Their guidance often treats “medium tests” as the place where a small number of tiers communicate properly, which is exactly the integration sweet spot.[^4]

Examples:
1. Database queries, migrations, transaction boundaries.
2. Serialization, schema evolution, backward compatibility.
3. Messaging, retries, dedupe, idempotency under real conditions.
4. Service-to-service calls with real HTTP and real headers.


### Contract tests
The underappreciated secret weapon in distributed systems.

Contract tests answer:

> Are we *still* speaking the same language across the boundary?

Martin Fowler’s framing is crisp: contract tests check the *contract* of external service calls, focusing on the **format and expectations**, not necessarily the exact data values.[^7] In other words, they verify the handshake between a consumer and a provider without requiring a full end-to-end environment.

Thoughtworks makes the “why now” argument for microservices: consumer-driven contract testing is a key part of a mature testing portfolio because it enables independent service deployments without accidentally breaking consumers.[^8]

A contract test asserts the handshake between consumer and provider:
request shape, response shape, defaults, error contracts, compatibility.

### End-to-end tests
Keep these few, but sacred.

End-to-end tests answer:
> Does the customer story still work?

Google’s testing guidance treats these as “large” tests: higher fidelity, but slower, more expensive, and more prone to flakiness than smaller tests, which is exactly why you keep them few and focused.[^3][^4]

A common trap is using end-to-end tests to compensate for missing lower-level tests. That’s how you get a flaky suite that everyone learns to ignore. The testing equivalent of buying a treadmill and using it to hang jackets.

Pick critical business journeys and test them like brakes on a car:
payment flow, login flow, upload-and-view flow.

## A “modern pyramid” that fits microservices better

Many teams quietly evolve toward this:

{% highlight text %}
End-to-End (tiny cap)
Integration / Component (solid middle)
Contract tests (thin band)
Unit (broad base)
{% endhighlight %}

This reduces the urge to build a giant end-to-end “everything suite” that is slow, brittle, and mostly good at wasting Tuesday afternoons.

## A practical decision rule: where should a test live?

Use this mental routing table:

1. If it is a business invariant, test it at the unit level first.
2. If it crosses a boundary you do not control, add a contract test.
3. If it depends on real infrastructure behavior, add an integration or component test.
4. If it is a critical customer journey, add an end-to-end test.

Test the truth close to the source.
Test the handshake at the boundary.
Test the journey only where it matters.

## Real world examples

### Example 1: Payments or loan servicing posting pipeline

A customer makes a payment. It gets authorized, posted, and the receipt is generated.

Must be tested:
1. Idempotency: the same payment request processed twice must not double-post.
2. Ledger correctness: principal vs interest allocation, fees, rounding, balance changes.
3. Atomicity: either all related records update, or none do. No “half paid” states.

Should be tested:
1. Retries and timeouts between services.
2. Duplicate events from the bus, out-of-order delivery, delayed settlement.
3. Reconciliation: what happens when tomorrow’s batch notices a mismatch?

Good to have:
1. Chaos: gateway latency spikes, downstream returns 503, does your system degrade or panic?
2. Property tests: ledger invariants remain true across random sequences.

A tiny invariant sketch:

{% highlight java %}
record Ledger(long debitCents, long creditCents) {
  long net() { return creditCents - debitCents; }
}

@Test
void ledgerNetMatchesArithmetic() {
  var r = new java.util.Random(0);
  for (int i = 0; i < 10_000; i++) {
    long debit = r.nextInt(1_000_000);
    long credit = r.nextInt(1_000_000);
    var l = new Ledger(debit, credit);
    org.junit.jupiter.api.Assertions.assertEquals(credit - debit, l.net());
  }
}
{% endhighlight %}

This does not prove correctness.
It proves you declared a truth, and you keep checking it.

### Example 2: Login plus token issuance

Must be tested:
1. Authorization boundaries: user A cannot access user B’s resources. Ever.
2. Token expiry and refresh: no immortal sessions.
3. Password reset and MFA: the “I lost access” path is where attackers live.

Should be tested:
1. Clock skew behavior in token validation.
2. Rate limiting and lockouts without harming real users.
3. Key rotation behavior in realistic rollout windows.

Good to have:
1. Fuzz JWT claims and headers.
2. Replay and session fixation abuse cases.

### Example 3: Document upload plus classification

Must be tested:
1. Correct customer association: misfiled documents are silent disasters.
2. Access control: only authorized users can view or reclassify.
3. PII handling: retention, redaction, encryption behavior.

Should be tested:
1. Corrupt PDFs, huge files, mixed encodings, virus scan failures.
2. Async pipeline correctness: retries, dead-letter paths, idempotent processing.
3. Search indexing lag and eventual consistency behavior.

Good to have:
1. Drift checks on classification confidence over time.
2. Canary documents monitored continuously.

## Closing

Testing will not make your product perfect.
It will keep your product honest.

Use tests to gain information about bugs, then fix them.
Do not let the presence of bugs shame you if your testing caught them.

A perfect product is a myth.
A low-quality product is a choice.

## References

[^1]: Gerald M. Weinberg, *Perfect Software*. (leanpub.com). <https://leanpub.com/perfectsoftware?utm_source=systemhalted.in>

[^2]: Dijkstra, *Reliability of programs*. (utexas.edu).<https://www.cs.utexas.edu/users/EWD/transcriptions/EWD03xx/EWD303.html?utm_source=systemhalted.in>

[^3]:  Simon Stewart, *Google Test Sizes*. (googleblog.com). <https://testing.googleblog.com/2010/12/test-sizes.html?utm_source=systemhalted.in>

[^4]: Titus Winters, Tom Manshreck, and Hyrum Wright. “Testing Overview.” Software Engineering at Google, n.d., <https://abseil.io/resources/swe-book/html/ch11.html>

[^5]: Michael Feathers, *Working Effectively With Legacy Code*. 1st Edition, Pearson

[^6]: Martin Fowler. “Integration Test.” (martinfowler.com). 2018, <https://martinfowler.com/bliki/IntegrationTest.html>

[^7]: Martin Fowler. “Contract Test.” *martinfowler.com*, 2011, <https://martinfowler.com/bliki/ContractTest.html>

[^8]: Thoughtworks. “Consumer-driven contract testing.” *Technology Radar*, 2015, <https://www.thoughtworks.com/en-us/radar/techniques/consumer-driven-contract-testing>


