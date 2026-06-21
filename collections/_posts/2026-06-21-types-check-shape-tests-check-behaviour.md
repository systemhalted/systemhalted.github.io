---
layout: post
title: Types Check Shape, Tests Check Behaviour
date: 2026-06-21
categories:
- Software Engineering
- Computer Science
tags:
- rust
- testing
- type-systems
- tdd
- software
comments: true
toc: true
description: 'Notes from building a small text editor in Rust, and what a green-but-wrong save() function taught me about the line between what a type system can prove and what only a test can.'
---

I am writing a small text editor in Rust to learn the language. Nothing fancy: a document model, open a file, save a file, and a long line of small steps after that. While building the save function I hit a bug that made me reconsider what tests are for and where the compiler takes over. These are the notes.

## A green test is not a correct program

The function was about as simple as they come. Write the buffer to a path, then mark the document as having no unsaved changes.

```rust
pub fn save(&mut self, path: &Path) -> io::Result<()> {
    std::fs::write(path, self.text());   // the Result here is silently dropped
    self.modified = false;
    Ok(())
}
```

I had written the following test as my TDD practice:

```rust
#[test]
fn save_writes_contents_and_clears_modified() {
    let path = std::env::temp_dir().join("save_test.txt");
    let mut doc = Document::from_str("abc");
    doc.insert(3, "def"); // buffer is now "abcdef", with unsaved changes

    doc.save(&path).unwrap();

    assert_eq!(std::fs::read_to_string(&path).unwrap(), "abcdef");
    assert!(!doc.is_modified()); // a successful save clears the dirty flag

    let _ = std::fs::remove_file(&path);
}
```

It built a document, made a change, saved it to a temporary file, read the file back, and checked that the contents matched and the document no longer reported unsaved changes. It passed given me the wrong confidence that my code works expectedly. But it introduced a bug.

The bug is on the first line. `std::fs::write` returns a `Result`, because writing to disk can fail: the disk is full, the directory does not exist, you lack permission. I dropped that result. So if the write failed, the function would still run `self.modified = false` and return `Ok(())`. The editor would report the file as saved, clear the unsaved-changes marker, and lose the user's work. For a text editor that is the one bug you cannot ship.

The test stayed green the whole time, because it only ran the happy path. The test proved the behaviour I checked. It says nothing about the behaviour I forgot.

## The compiler reviews shape, not intent

I did not catch the bug. The compiler did.

```
warning: unused `Result` that must be used
```

Rust marks `Result` as `#[must_use]`[^mustuse], so it flags every call that produces a failure value you then ignore. Most languages stay silent here. Rust did not, and it was right.

But the compiler could warn me, not stop me. I could have written this instead:

```rust
let _ = std::fs::write(path, self.text());   // explicitly discard it
self.modified = false;
Ok(())
```

That compiles with no warning at all. The type checker is satisfied: the signature returns a `Result`, a `Result` is returned, the borrow rules[^borrow] hold. It has checked the shape of the code and found it sound. What it cannot check is what I meant, that a failed write must not clear the modified flag and must not be reported as success. The shape is right; the meaning is wrong, and here the compiler cannot tell the difference.

So the compiler is a real second reviewer. But it only checks the shape of the code: that the types line up, that the `Result` is accounted for, that the borrows are valid. It does not check that the code does the right thing.

## A regression test only counts once you have seen it fail

The fix is one character, the `?` operator, which returns the failure instead of swallowing it.

```rust
std::fs::write(path, self.text())?;
self.modified = false;
Ok(())
```

The fix was not the lesson. The lesson was that I had no test that would have caught the bug. But adding the `?` without adding a test would leave me trusting the code for no reason. So I wrote the test that should have existed first.

```rust
#[test]
fn failed_save_surfaces_error_and_keeps_modified() {
    let mut doc = Document::from_str("important data");
    doc.insert(0, "!"); // the document now has unsaved changes

    // a directory that does not exist, so the OS write is forced to fail
    let bad_path = std::env::temp_dir().join("no_such_dir").join("file.txt");
    let result = doc.save(&bad_path);

    assert!(result.is_err());     // the failure must reach the caller
    assert!(doc.is_modified());   // and the buffer must still be dirty
}
```

Then I put the bug back, ran the suite, and watched this test go red. Only then did I restore the fix and watch it go green.

This sounds like ceremony. It is not. Until you have watched a regression test fail for the reason you expect, you have no evidence it would catch anything. You only know that it passes, and the first section already showed how little that is worth.

## Types and tests answer different questions

This is the rule I would keep if I could keep only one.

A type system proves a property holds for every input, but only properties you can write as structure: this value is never null, every `Result` is handled, this `match` covers every case.

You can push more behaviour into types than that suggests. The typestate pattern[^typestate] encodes a rule into a type, so that an illegal operation does not compile instead of failing a test. Our own `save` bug can be closed this way. The bug was clearing the modified flag after a write that might have failed, so make the clearing depend on proof that the write succeeded:

```rust
struct Saved;   // nothing outside this module can construct one

fn write(&self, path: &Path) -> io::Result<Saved> { /* ... */ }
fn mark_clean(&mut self, _proof: Saved) { self.modified = false; }
```

Now `mark_clean` cannot be called without a `Saved`, and the only thing that hands you a `Saved` is a `write` that returned `Ok`. The exact bug from the first section no longer compiles.[^receipt] The boundary between what a type proves and what a test proves is not fixed; it moves with how much you choose to encode.

What stays out of reach, at least in Rust, is value-level correctness: the relationship between specific input and output values. That needs dependent types, which Rust does not have. The type checker has no opinion on whether inserting `" world"` at index 5 of `"hello"` gives `"hello world"` or `"worldhello"`. Both are valid `String`s. Only a test says which one you meant.

The instruction that falls out of this is short.

> Do not test what the type system has already made impossible. Test the behaviour the type system is silent about.

An example came up in the next step. A document needs to remember the file it came from, but a new, untitled buffer has not come from anywhere. The honest type is `Option<PathBuf>`, and Rust will not let you read the path without handling the case where there is none. The "I forgot to check for the missing file" bug is not caught by a test here. The program that contains it does not compile. The type is the test.

## "Test everything that can fail" is too blunt

I used to carry a simple rule: every operation that can fail gets a failure test. It made true sense in Java. After the save bug I wrote one for `open` too, the function that reads a file, asserting that opening a missing file returns an error. Then I deleted it.

The save failure test is worth keeping, but not because saving can fail. It is worth keeping because `save` changes state on the way to succeeding: it clears the modified flag. The assertion that matters is `doc.is_modified()`, not `result.is_err()`. The failure path can leave state wrong, and the test guards that state.

`open` just builds a value and returns it. It changes nothing and leaves nothing wrong if it fails. The only thing a failure test could check is whether I propagated the error instead of swallowing it. That is thin, with nothing behind it to protect. So the rule sharpened:

> A failure test is worth its keep in proportion to the state a failure could leave wrong. Where failure only propagates cleanly, with no state left wrong, the test has nothing to guard.

That is not an argument for testing less out of laziness. It is an argument for testing where things can actually break, instead of spreading assertions evenly out of habit.

## The point

This is not an argument against tests, or against types. It is an argument for knowing which one you are leaning on. Lean only on tests and you will keep writing assertions to re-establish guarantees a good type system gives you for free, at compile time, for every input. Lean only on types and you will ship code that is well-formed and quietly wrong: green in every structural sense, still losing files.

Let the type system carry what it can: null-safety, exhaustiveness, the fact that a failure cannot be ignored, and as much of your state machine as you are willing to encode. Spend your tests on the behaviour that is left over. You can move that line, and typestate carries more than you would expect, but wherever you draw it, do not ask a type to prove what only a test can, or a test to re-prove what the type already guarantees.

And how far the line can move depends on the language. I could have written this editor in Java. It would run, and it would be memory-safe. But the editor leans on two guarantees that Java's type system will not hold me to. The first is that absence has a single shape: Rust has no `null`, so a value that might not be there is an `Option`, and the compiler will not let me touch it without handling the empty case. Java has `Optional`[^java], but it sits beside `null` rather than replacing it, and nothing stops me from calling `.get()` and learning my mistake at runtime, so there the guarantee is a convention I have to keep rather than a rule the compiler keeps for me. The second is move semantics: a value can be used once and then be gone. Java can make the proof-of-save *exist* — a private constructor and a factory will do that — but it cannot make it *spent*; nothing stops me clearing the flag with the same token twice. Rust takes the value away when it is used, and that is the part Java has no equivalent for. In both cases the work does not vanish; it moves from the compiler to my tests and my discipline. The reason to reach for Rust is not that the editor is otherwise impossible; it plainly is not. It is that a more expressive type system moves the line, and settles more of the program's correctness before a single test runs.

## References and Notes

[^mustuse]: Rust's `#[must_use]` attribute and the lint behind the warning: <https://doc.rust-lang.org/reference/attributes/diagnostics.html#the-must_use-attribute>

[^borrow]: References and borrowing in Rust, including the rules the borrow checker enforces: <https://doc.rust-lang.org/book/ch04-02-references-and-borrowing.html>

[^typestate]: Cliff L. Biffle, "The Typestate Pattern in Rust," a thorough walk through encoding state into types: <https://cliffle.com/blog/rust-typestate/>

[^receipt]: This sketch is illustrative, not airtight. The `Saved` token is not bound to a particular document or path, so within the module that defines these methods you could still write to one file and clear a different document's flag. A rigorous version would tie the proof to the instance; the point here is only that the rule can be pushed into the type at all.

[^java]: Kotlin, on the same JVM, enforces null-safety in its type system, distinguishing `String` from `String?` and checking it at compile time, which closes the first gap. And Java's sealed types with a pattern-matching `switch` give compile-time exhaustiveness over a closed set of cases — the same "every case is handled" guarantee Rust's enums provide — and it can even encode method-presence typestate, so it carries more behaviour than the body alone might suggest. What stays particular to Rust is linearity: a value that is consumed when it is used. The broader point, that the type system's power sets how far the line can move, is what holds.
