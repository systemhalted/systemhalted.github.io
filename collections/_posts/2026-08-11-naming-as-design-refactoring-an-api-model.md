---
layout: post
title: 'Naming as Design: Refactoring an API Model'
date: 2026-08-11 00:30:00 -0500
categories:
- Software Engineering
- Computer Science
tags:
- naming
- api-design
- java
- openapi
- design
- software
comments: true
toc: true
description: 'Taking one badly named order model -- Java record and OpenAPI schema -- through four passes: types that test values, names that reveal intention, duplication removed, and speculative fields deleted.'
---

In an [earlier post](/2026/07/23/my-naming-philosophy/) I wrote down my naming rules: Kent Beck's four rules of simple design read as naming rules, plus Strunk's "omit needless words" and Russ Cox's advice that a name's length should not exceed its information content. Rules stated in the abstract are easy to nod along to, so this post applies them to one concrete model. I start with an order model that I would not want to inherit, and take it through four passes, one rule per pass.

The example is invented, but nothing in it is exotic. I have reviewed models that looked like this, and I have written a few.

## The starting point

The model, as a Java record and as the OpenAPI schema that exposes it:

```java
public record OrderData(
    String orderIdString,
    String customerEmailAddressString,
    String orderStatusValue,
    String orderTotalAmountValue,
    String orderCurrencyCodeString,
    String createdDateTimestamp,
    String updatedDateTimestamp,
    String orderNotesText,
    Boolean isOrderActiveFlag,
    String futureDiscountCode,
    Map<String, Object> extraAttributes
) {}
```

```yaml
OrderData:
  type: object
  properties:
    orderIdString:              { type: string }
    customerEmailAddressString: { type: string }
    orderStatusValue:           { type: string }
    orderTotalAmountValue:      { type: string }
    orderCurrencyCodeString:    { type: string }
    createdDateTimestamp:       { type: string }
    updatedDateTimestamp:       { type: string }
    orderNotesText:             { type: string }
    isOrderActiveFlag:          { type: boolean }
    futureDiscountCode:         { type: string }
    extraAttributes:            { type: object }
```

Nothing here is wrong in the sense that a test would catch. It compiles, it serializes, it round-trips. What is wrong is that the model makes no checkable claims: nine of its eleven fields accept any string at all, the names repeat themselves, and two fields exist for reasons nobody can state. Each pass below fixes one of those problems.

## Pass 1 -- Runs the tests: give every value a type that can reject it

Beck's first rule is that the code passes its tests. For a model, my reading is: the type of each field should be able to test the value the field must hold. A `String` passes everything, so it tests nothing. The first pass replaces every stringly-typed field with a type that can reject a bad value.

```java
public record Email(String value) {
    public Email {
        if (!value.matches("[^@\\s]+@[^@\\s]+\\.[^@\\s]+")) {
            throw new IllegalArgumentException("not an email address: " + value);
        }
    }
}
```

(Real email validation is more involved than one regex, and if you need it to be exact you delegate to a library. The point is not the regex; it is where the check lives. Any value of type `Email` has passed it, so code that receives an `Email` never has to re-check.)

The same treatment for the rest: an `OrderId` record that enforces the id format, an `OrderStatus` enum instead of a free-form status string, and `Instant` for the two timestamps, since the JDK already has a type that rejects malformed dates. The amount and the currency merge into one type, because a monetary amount without its currency is not a value you can do anything safe with:

```java
public record Money(BigDecimal amount, Currency currency) {
    public Money {
        if (amount.scale() > currency.getDefaultFractionDigits()) {
            throw new IllegalArgumentException("too many decimal places for " + currency);
        }
    }
}
```

After the first pass:

```java
public record OrderData(
    OrderId orderIdString,          // types fixed; the names are the next pass
    Email customerEmailAddressString,
    OrderStatus orderStatusValue,
    Money orderTotalAmountValue,
    Instant createdDateTimestamp,
    Instant updatedDateTimestamp,
    String orderNotesText,
    Boolean isOrderActiveFlag,
    String futureDiscountCode,
    Map<String, Object> extraAttributes
) {}
```

The schema gets the same pass. OpenAPI cannot run a constructor, but `format`, `enum`, `pattern`, and range constraints are its way of testing values before they reach your code:

```yaml
orderIdString:
  type: string
  pattern: '^ord_[0-9a-z]{12}$'
customerEmailAddressString:
  type: string
  format: email
orderStatusValue:
  type: string
  enum: [pending, paid, shipped, delivered, cancelled]
orderTotalAmountValue:
  $ref: '#/components/schemas/Money'
createdDateTimestamp:
  type: string
  format: date-time
```

Every constraint added here is a test that runs on every request, in every environment, with no test suite involved. Alexis King's ["Parse, don't validate"](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/) makes the general argument: once a value has parsed into a narrower type, the rest of the program can rely on it instead of re-checking it. This is also the pass that caught a design error the original model hid -- the amount and currency were two independent fields that could disagree, and `Money` makes that state unrepresentable.

## Pass 2 -- Reveals intention: say what the field is for

The types are now right and the names are still bad. The second pass renames each field to say what it is for, and Strunk's rule 13 -- omit needless words -- does most of the work. For each name, strike the words that carry no information and see what is left.

- `customerEmailAddressString`: `String` repeats the type (and is now false -- the type is `Email`). `Address` repeats what *email* already implies. What is left is `customerEmail`.
- `createdDateTimestamp` and `updatedDateTimestamp`: `Date` and `Timestamp` both describe the type, which the declaration already shows. What the reader needs is the *event*: `createdAt`, `updatedAt`.
- `orderNotesText`: `Text` describes the type. But striking it exposes a different failure: notes for whom, about what? If I cannot make a name specific, I usually have not decided what the field is for. In this system the field holds the customer's instructions to the courier, so the honest name is `deliveryInstructions`.
- `isOrderActiveFlag`: `Flag` repeats the type. But after striking it, I still cannot say what *active* means here -- not cancelled? not delivered? recently touched? A field whose meaning I cannot state is a problem for a later pass; renaming it now would not fix it.

An intention-revealing name matters more in the schema than in the Java, because a consumer of the API cannot read the implementation. They have the field name, the type, and the description string, and most will read only the name.

## Pass 3 -- No duplication: stop repeating the context

Every remaining name still says *order*, inside a type that already says it. `order.orderId` says order twice; so does `OrderData.orderStatusValue` -- three times, if you count `Value` restating the type. Once a field lives inside `Order`, the context carries that word, and repeating it adds length without adding information. The `Data` suffix on the record name is the same duplication one level up: it describes what every record is.

This is Russ Cox's `getParametersAsNamedValuePairArray` point at the field level -- the only interesting word in that name is *parameters*, and the only interesting words in `orderStatusValue` are *status*.

The pass also catches duplication that is not in the names. `isOrderActiveFlag` turned out to mean "status is neither cancelled nor delivered" -- it restates `status`, as data. Two fields carrying the same fact will eventually disagree. Since the value is derivable from `status`, I delete the field rather than rename it; if the convenience matters, an `isActive()` method on the record can compute it.

```java
public record Order(
    OrderId id,
    Email customerEmail,
    OrderStatus status,
    Money total,
    Instant createdAt,
    Instant updatedAt,
    String deliveryInstructions,
    String futureDiscountCode,
    Map<String, Object> extraAttributes
) {}
```

## Pass 4 -- Fewest elements: delete what has no reason to exist

Two fields remain that no current feature reads.

`futureDiscountCode` was added because a discounts feature is expected someday. When that feature arrives it will have real requirements, and this field -- named, typed, and shaped before any of them were known -- is unlikely to match. Until then it is surface area: it appears in generated clients, consumers store it, and when the real feature ships it will have to be deprecated in favour of whatever is actually needed.

`extraAttributes` is a bigger problem, because it weakens the whole schema rather than just adding an unused field. A `Map<String, Object>` field says that anything may appear here, with any type, and none of it is documented. Whatever goes into that map is exactly the data that should have been a named, typed field, and once consumers start passing values through it you can never remove it. The only cheap time to delete it is while it is still empty.

The final model:

```java
public record Order(
    OrderId id,
    Email customerEmail,
    OrderStatus status,
    Money total,
    Instant createdAt,
    Instant updatedAt,
    String deliveryInstructions
) {}
```

```yaml
Order:
  type: object
  required: [id, customerEmail, status, total, createdAt, updatedAt]
  properties:
    id:
      type: string
      pattern: '^ord_[0-9a-z]{12}$'
    customerEmail:
      type: string
      format: email
    status:
      type: string
      enum: [pending, paid, shipped, delivered, cancelled]
    total:
      $ref: '#/components/schemas/Money'
    createdAt:
      type: string
      format: date-time
    updatedAt:
      type: string
      format: date-time
    deliveryInstructions:
      type: string
      maxLength: 500
```

Seven fields instead of eleven, every one of them constrained, and every name down to the words that carry information. Cox's rule about length and scope explains why the final names can be this short: `id` is unambiguous precisely because it is read inside `Order`, where the context supplies the rest. The same field flattened into a log line or an analytics event should be `orderId` again, because there the context is gone and the name has to carry it.

## Trade-offs

The refactor above is presented as if it were free. It is not, and it helps to know the costs before applying it.

**Wrapper types are ceremony, and serialization notices.** Every `Email`-style type needs a Jackson `@JsonValue` and `@JsonCreator` (or the equivalent in your framework) so it serializes as a plain string rather than a nested object. Records have made the class definitions nearly free, but the serialization plumbing is a real, one-time cost per type, and on a small internal tool it may not pay for itself.

**Some strings are honestly strings.** `deliveryInstructions` stayed a `String` because free text is genuinely a string: there is no constraint a `DeliveryInstructions` type could test beyond a length cap, and the schema's `maxLength` already covers that. Wrapping it would add a type without adding a check. The test I use: if the constructor would be empty, the wrapper adds nothing.

**Renaming a published field is a breaking change.** Everything in this post is cheap at design time and expensive after the first consumer integrates. Once `orderIdString` is in production traffic, fixing it means versioning the API or carrying both names through a deprecation cycle. This is the strongest argument for doing the naming work before v1 ships rather than after.

**Short names depend on their context surviving.** `id` is right inside the schema and wrong in a CSV export. If a name will be read where its enclosing context is stripped away, it has to carry the context itself. Cox's rule decides both cases; it just gives different answers.

**A consistent team convention beats my preference.** If the codebase I am in writes `orderId` on every entity, I write `orderId`. A reader who can predict every name in the system is better off than one who has to learn which files follow which philosophy.

## Sources

- [Kent Beck's four rules of simple design](https://martinfowler.com/bliki/BeckDesignRules.html), as summarized by Martin Fowler
- [The Elements of Style, rule 13: omit needless words](https://www.bartleby.com/lit-hub/the-elements-of-style/iii-elementary-principles-of-composition/#13), Strunk
- [Notes on naming](https://research.swtch.com/names), Russ Cox
- [Parse, don't validate](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/), Alexis King
- [My naming philosophy](/2026/07/23/my-naming-philosophy/), the short version of this post
