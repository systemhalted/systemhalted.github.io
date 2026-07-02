---
layout: post
title: "Property-Based Testing: Testing Rules Instead of Examples"
date: 2026-07-02
categories:
- Software Engineering
- Computer Science
tags:
- rust
- testing
- property-based-testing
- tdd
- software
comments: true
toc: true
description: An example test checks the inputs you happened to choose. A property-based test states a rule and lets the framework generate inputs that try to break it. Notes from continuing a small text editor in Rust.
org_source: org/posts/2026-07-02-property-based-testing.org # generated file — edit the .org source
---
In an [earlier post](/2026/06/21/types-check-shape-tests-check-behaviour/) I wrote about a small text editor I am building in Rust, and a `save` function that passed its test while being wrong. The test built a document, changed it, saved it, read the file back, and checked that the contents matched. It was green. The implementation dropped the `Result` from the disk write, so a failed save would still report success and clear the unsaved-changes flag. The test and the bug lived together without any conflict, because the test only ever ran the happy path.

That post was about the boundary between what a type system can prove and what only a test can. There is a separate limitation worth looking at, one that has little to do with that particular bug. An example test only runs the input I give it. My save test proves something about the string `abcdef` written to a temporary file, and nothing about the other inputs the function will see. I chose the input, so the input agrees with me. Writing more example tests does not remove this, because I choose those inputs too.


## From examples to a property

Take `insert` and `delete` on the document model. The usual way to test them is with an example.

```rust
#[test]
fn insert_then_delete_restores_buffer() {
    let mut doc = Document::from_str("hello");
    doc.insert(5, " world");        // "hello world"
    doc.delete(5, 11);              // back to "hello"
    assert_eq!(doc.text(), "hello");
}
```

This test passes, and it is not a bad test. But look at what it actually asserts: that inserting `" world"` at index 5 of `"hello"`, and then deleting that range, gives back `"hello"`. That is one point in a large space of possible inputs. The rule I care about is not about `"hello"` at all. It is this: for any document, inserting a string and then deleting exactly that range returns the original document. I wrote a test about one case of the rule because a single case is the only thing an example test lets me state.

Property-based testing lets me state the rule and let the framework choose the inputs. Instead of picking the input, I describe the range of valid inputs, state what must be true, and the framework generates many cases and tries to find one that fails. In Rust the common tool for this is the `proptest` crate[^proptest].

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn insert_then_delete_is_identity(base in ".*", ins in ".*", at in 0usize..=usize::MAX) {
        let mut doc = Document::from_str(&base);
        let at = at % (doc.len() + 1);          // an offset into the buffer
        let before = doc.text().to_string();

        doc.insert(at, &ins);
        doc.delete(at, at + ins.len());

        prop_assert_eq!(doc.text(), before);
    }
}
```

`proptest` runs this body a few hundred times with different generated values, and the test passes only if the property holds for all of them. I am no longer asserting a fact about `"hello"`. I am asserting a fact about `insert` and `delete`.


## Reading the generator line

Most of the work in that test is in the signature, so it is worth going through it slowly.

Each `name in strategy` clause defines one generated argument. A strategy is the `proptest` term for something that knows two things: how to produce a random value, and how to shrink that value toward something smaller when a test fails. On each run, `proptest` draws a value from each strategy and calls the body with them. The `in` reads a little like the `in` of a `for` loop, but it is not walking a fixed list. It is drawing from a described set of inputs.

`base in ".*"` and `ins in ".*"` generate strings. The literal `".*"` is read as a regular expression, and the strategy produces strings that match it. In that expression `.` means any character and `*` means zero or more of them, so `".*"` matches almost any string: the empty string, `"hello"`, a single emoji, a two-byte character such as `"é"`, whitespace, or control characters. This wide range is deliberate. `".*"` will produce characters that take more than one byte, and those are the inputs I do not think to type by hand, which turns out to matter here. If I wanted a narrower set of inputs I would use a narrower expression, such as `"[a-z]{1,10}"` for one to ten lowercase letters, or `"[0-9]+"` for a run of digits. Here I want the widest set I can get.

`at in 0usize..=usize::MAX` generates an integer. The strategy here is an ordinary Rust range. `proptest` provides a `Strategy` implementation for the standard range types, so a range can be handed to it directly as a generator that produces values inside the range. Reading the bounds from left to right: `0usize` is the low end, zero, written as a `usize`, which is Rust's pointer-sized unsigned integer and the type used for indexing. The `..=` operator makes the range inclusive, so the upper value is part of the range. `usize::MAX` is the largest value a `usize` can hold. The `usize` suffix on `0usize` is not cosmetic. Both ends of a range must have the same type, and without it the compiler cannot tell whether I meant a `u32`, an `i64`, or something else. So `at` is any index from zero to the maximum.

This raises a fair question. The generated integer can be as large as `usize::MAX`, about 1.8 billion billion on a 64-bit machine, while a short document has only a handful of positions. A five-byte string like `"hello"` has just six offsets, zero through five. So almost every raw value the generator produces lands far past the end of the buffer rather than inside it. Why draw from the whole `usize` range at all? The reason is that the three strategies are evaluated independently. The generator for `at` does not know how long the `base` string it is paired with will be, so it cannot produce an index that is valid for that particular document. The first line of the body deals with this.

```rust
let at = at % (doc.len() + 1);   // an offset into the buffer
```

The modulo maps any generated integer into the range `0..=doc.len()`, where `doc.len()` is the length of the document in bytes. The range is inclusive at the top because you can insert at the end of the buffer as well as inside it. Generating a wide value and then mapping it into range is a common pattern with `proptest`, because it keeps every generated value usable instead of throwing away the ones that fall out of range. There is a more precise tool for producing an index into a generated collection, the `prop_flat_map` combinator, which lets one strategy depend on the value another produced. For a single index the modulo is simpler.

So the signature reads as follows: for any strings `base` and `ins`, and any index `at` mapped into range, the body must hold. `proptest` runs the body many times with different values, and the test passes only if the property holds for all of them.


## When a property fails

Run this property as written and it does not reach the assertion. It panics, and not on `"hello"`. It panics on an input I would not have typed into a test by hand.

A raw generated input is not much use as a bug report. If the framework told me the test failed on a four thousand character random string, that would be a puzzle to work through, not a defect I can read. What makes property-based testing practical is shrinking. When `proptest` finds a failing input, it does not report that input directly. It looks for the smallest and simplest input that still fails, using shorter strings, smaller indices, and values closer to zero, and reports that instead. The failure shrinks down to something like this.

```text
minimal failing input:
    base = "é"
    ins  = ""
    at   = 1

panic: byte index 1 is not a char boundary
```

That is a report I can act on, and the surprise is where the panic comes from. It is not a bug in `insert` or `delete`. It is my own line, `at % (doc.len() + 1)`. In Rust a string index is a byte offset, and `len()` returns a length in bytes, so the modulo gives me some offset between zero and the byte length. But not every byte offset is a place you are allowed to edit. An edit must land on a UTF-8 character boundary, and `insert` panics when it does not. The character `é` is two bytes, so the only valid positions are `0` and `2`; the offset `1` falls inside the character. The generator produced the smallest string and index that break an assumption I had written into the test without noticing it: that any offset from zero to the length is a valid place to insert.

The fix is to generate only offsets that fall on character boundaries. Rust gives me the boundaries through `char_indices`, and I add the end of the string as the last position.

```rust
use proptest::prelude::*;

fn char_boundary_offsets(s: &str) -> Vec<usize> {
    s.char_indices()
        .map(|(i, _)| i)
        .chain(std::iter::once(s.len()))
        .collect()
}

proptest! {
    #[test]
    fn insert_then_delete_is_identity(base in ".*", ins in ".*", raw_at in 0usize..=usize::MAX) {
        let offsets = char_boundary_offsets(&base);
        let at = offsets[raw_at % offsets.len()];   // a valid edit position

        let mut doc = Document::from_str(&base);
        let before = doc.text().to_string();

        doc.insert(at, &ins);
        doc.delete(at, at + ins.len());

        prop_assert_eq!(doc.text(), before);
    }
}
```

There is a more general point here, beyond the Unicode detail. A property test does not only run more inputs than an example. It makes me say what a valid input is. Writing the example test, I never had to define the set of legal insertion points, because I only used position 5 of `"hello"`, which happens to be legal. The property could not be written until I stated, in code, that a legal position is a character boundary. So the generator did not simply find a case I had forgotten. It exposed an assumption I had never written down, which is what happens when a rule has to hold for every input rather than for the one I picked.

The type system does not close this gap. `String` guarantees the buffer is valid UTF-8, but an index into it is a plain `usize`, and the type says nothing about whether that `usize` lands on a boundary. That check happens at runtime, and until I wrote the property it was happening nowhere in my tests.


## Where property-based testing helps, and where it does not

It would be easy to read this and decide that property tests should replace example tests. They should not, any more than tests replace types. Each answers a different question, and property testing has a cost. A good property is harder to find than a good example, and a weak property is worse than no test at all.

The cost is in finding the rule. "For input `"hello"`, expect `"hello world"`" takes a second to write. "For all documents and all edits, this relationship holds" takes real thought, and if the rule is slightly wrong the test is either flaky or empty. The common mistake is a vacuous property, one that cannot fail.

```rust
prop_assert!(doc.len() >= 0);       // len() is usize; always true
```

That runs a few hundred times, passes every time, and checks nothing. A property that is merely true is not the same as a property that constrains the code. The useful properties describe a relationship tight enough that a wrong implementation cannot satisfy it: round-trips such as `decode(encode(x)) == x`, idempotence such as `f(f(x)) == f(x)`, order-independence where applying two edits in either order gives the same result, and conservation of some quantity such as length or character count. If I cannot name a relationship like that, an example test is the honest choice, and a property adds nothing.

Here is the rule I settled on. A property test earns its place when there is a rule that must hold across many inputs, not a single value I am checking. `save` then `load` should return the same buffer, and that is a rule. "The About dialog shows version 2.1" is a single value, and writing it as a property gains nothing.


## Types, examples and properties

I now think of three tools rather than two, each covering what the previous one cannot.

Types rule out illegal shapes before the program runs. A `Result` that must be used, an `Option` that cannot be read without handling the empty case, a closed enum that forces every branch to be handled. The compiler settles these for every input at once, and this is the cheapest of the three.

Example tests check specific behaviour that the types allow but do not pin down. That inserting `" world"` at index 5 of `"hello"` gives `"hello world"` and not `"worldhello"` is a fact about values, and the type checker has no opinion on it. An example fixes one such fact.

Property tests cover the space in between, the behaviour that must hold across all the inputs the type still allows and that no single example can cover. The UTF-8 boundary case sits there. It is legal according to the type, missed by the examples, and wrong in general. The useful thing is to be clear about how behaviour will be evaluated before writing the code, which is the [test-first](/2025/12/09/tdd-revisted/) instinct. A property is one clear way to state that evaluation, because it forces me to say what must always be true rather than what happened to be true the one time I ran the code.

The three fit together in order. Push what you can into types, so the compiler proves it for every input. Use examples to record the specific behaviour you have decided on. Use properties for the rules that must hold everywhere and that you would never cover by hand.


## Summary

An example test checks the inputs I thought of. A property-based test states a rule and lets the framework generate inputs that try to break it. That is the difference that matters. On my own I tend to write the tests my code already passes, because I imagine the same cases when I write the code and when I test it. The generator does not share that imagination, and shrinking makes what it finds small enough to read and fix. Writing the property also forces me to say what a valid input is, which is often where the real gap turns out to be. The reason to reach for property testing is not that the code is otherwise untestable. It is that it exercises the inputs I would not have chosen, and in a text editor those are often the inputs a real user will produce.


## References and Notes

[^proptest]: `proptest` is a property-testing framework for Rust with shrinking driven by its generators. Documentation and the book: <https://proptest-rs.github.io/proptest/>. Rust's other well-known option, `quickcheck` (<https://github.com/BurntSushi/quickcheck>), follows the original Haskell QuickCheck more closely: it mirrors that library's `Arbitrary` typeclass as an `Arbitrary` trait, so generation and shrinking both live on the type. `proptest` instead takes its generator-driven shrinking from Python's Hypothesis (<https://hypothesis.readthedocs.io/>), where the strategy that built a value also knows how to shrink it. Both Rust crates descend from Claessen and Hughes, "QuickCheck: A Lightweight Tool for Random Testing of Haskell Programs" (ICFP 2000): <https://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quick.pdf>, the paper that introduced testing stated properties over generated inputs.
