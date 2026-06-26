---
layout: post
title: Types Check Shape, Tests Check Behaviour
date: 2026-06-21
last_modified_at: 2026-06-25
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

I am writing a small text editor in Rust to learn the language -- a document model, opening a file, saving a file, and a long line of small steps after that -- and while building the `save` function I hit a bug that made me reconsider what tests are for and where the compiler takes over. These are the notes.

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

It built a document, made a change, saved it to a temporary file, read the file back, checked that the contents matched, and confirmed the document no longer reported unsaved changes. The test passed, which would normally be the end of it, except that the implementation had a bug on the first line.

`std::fs::write` returns a `Result`, because writing to disk can fail in any of the ordinary ways: the disk fills up, the directory does not exist, the process lacks permission. The function ignored that return value, so a failed write would still fall through to `self.modified = false` and then `Ok(())`. The editor would report the file as saved, clear the unsaved-changes marker, and lose the user's work, which is the one bug a text editor cannot ship. The test stayed green the whole time because it only ran the happy path, and a passing happy-path test says nothing about the behaviour on the failure paths it never visits.

## The compiler reviews shape, not intent

I missed the bug, but the compiler flagged it:

```text
warning: unused `Result` that must be used
```

Rust marks `Result` as `#[must_use]`[^mustuse], so the lint fires when a fallible call's return is dropped on the floor. Most languages would stay silent here; Rust does not, and it was right to complain.

The warning is real help, but it is still only a warning. I could have written this instead and quieted it:

```rust
let _ = std::fs::write(path, self.text());   // explicitly discard it
self.modified = false;
Ok(())
```

That compiles cleanly. The type checker is satisfied: the signature returns a `Result`, a `Result` is returned, the borrow rules[^borrow] hold, the shape of the program is right. What the compiler has no way of checking is what I meant by it -- that a failed write must not clear the modified flag, that it must not be reported as success, that in a text editor a dirty buffer is not a boolean but a promise to the user.

This is what the compiler is good at and where it stops. It checks that the types line up, that fallibility is visible in signatures, that a `Result` is not accidentally ignored, that the borrows are valid; it does not check that the program does the right thing with any of those things once it has them.

## A regression test only counts once you have seen it fail

The fix is one character -- the `?` operator -- which turns the dropped result into a propagated one:

```rust
std::fs::write(path, self.text())?;
self.modified = false;
Ok(())
```

If the write fails, the function exits before clearing the modified flag. The interesting part is not the fix but the realisation that I had no test that would have caught the bug. Adding `?` without adding a test would leave me trusting the code for no reason at all, so I wrote the test that should have existed from the start.

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

Then I put the bug back, ran the suite, watched this test go red, restored the fix, and watched it go green. Putting the bug back to confirm the test fails for the right reason sounds like ceremony but is not -- a regression test you have never seen fail is one you trust by faith, and the first section already showed how little a passing test is worth on its own.

## Types and tests answer different questions

This is the rule I would keep if I could keep only one. A type system is good at making certain kinds of lies impossible: a value that may be absent cannot pretend to be present, a fallible operation cannot pretend to be infallible, a closed set of cases cannot pretend one branch does not exist. That is powerful, but it is structural. Rust can make the failure visible, warn me when I accidentally ignore it, and force the code to admit that saving may fail, but it cannot encode the editor's rule that if saving fails, the document must remain dirty. That rule lives at the level of behaviour, not shape.

You can push more behaviour into types than that suggests. The typestate pattern[^typestate] encodes a rule into a type, so that an illegal operation does not compile instead of failing a test. The `save` bug can be narrowed this way by making the clearing of the modified flag depend on a value that only a successful write can produce:

```rust
struct Saved;   // nothing outside this module can construct one

fn write(&self, path: &Path) -> io::Result<Saved> { /* ... */ }
fn mark_clean(&mut self, _proof: Saved) { self.modified = false; }
```

Now `mark_clean` cannot be called without a `Saved`, and the only thing that hands one back is a `write` that returned `Ok`, so the exact bug from the first section is harder to write by accident.[^receipt] The boundary between what a type can prove and what only a test can prove is not fixed; it moves with how much you choose to encode.

What stays out of reach, at least in Rust, is value-level correctness -- the relationship between specific input and output values. That needs dependent types, which Rust does not have. The type checker has no opinion on whether inserting `" world"` at index 5 of `"hello"` gives `"hello world"` or `"worldhello"`; both are valid `String`s, and which one you meant is a question only a test can answer. The instruction that falls out of this is short: do not test what the type system has already made impossible, and do test the behaviour the type system is silent about. A small example came up in the next step. A document needs to remember the file it came from, but a new, untitled buffer has not come from anywhere, so the honest type for that field is `Option<PathBuf>`, and Rust will not let you read the path without handling the case where there is none. The "I forgot to check for the missing file" bug is not caught by a test here; the program that contains it does not compile, and writing a test for it would only re-prove what the compiler has already proven.

## "Test everything that can fail" is too blunt

I used to carry a simple rule: every operation that can fail gets a failure test. It made sense in the Java world I grew up in, and after the save bug I wrote one for `open` too -- a test asserting that opening a missing file returns an error. Then I deleted it.

The save failure test is worth keeping, but not because saving can fail. It is worth keeping because `save` changes state on the way to succeeding: it clears the modified flag. The assertion in that test that actually matters is not `assert!(result.is_err())` but `assert!(doc.is_modified())`, which guards the state that a failed save could otherwise leave wrong. `open` is different; it builds a value and returns it, changing nothing and leaving nothing wrong when it fails. The only thing a failure test there could check is whether I propagated the error instead of swallowing it, which is thin, with no state behind it to protect.

So the rule sharpened into something narrower: a failure test earns its place in proportion to the state a failure could leave wrong, and where failure only propagates cleanly there is little for it to guard. That is not an argument for testing less out of laziness, but for putting tests where things can actually break instead of spreading them evenly out of habit.

## The point

This is not an argument against tests or against types, but for knowing which of the two you are leaning on at any given moment. Lean only on tests and you will keep writing assertions to re-establish guarantees a good type system would give you for free, at compile time, for every input. Lean only on types and you will ship code that is well-formed and quietly wrong: green in every structural sense, still losing files. The healthier division is to let the type system carry what it can -- null-safety, exhaustiveness, fallibility made visible, and as much of your state machine as you are willing to encode -- and to spend your tests on the behaviour that is left over.

That line moves. Typestate carries more than people expect, and dependent types would carry more again, but wherever you draw it for a given program the rule is the same: do not ask a type to prove what only a test can, or a test to re-prove what the type already guarantees. How far the line can move also depends on the language. Rust leans on two guarantees that Java's type system holds you to less strictly. The first is that absence has a single shape: Rust has no `null`, so a value that might not be there is an `Option` and the compiler will not let me touch it without handling the empty case, whereas Java's `Optional`[^java] sits beside `null` rather than replacing it and leaves `.get()` available to learn my mistake at runtime. The second is move semantics: Java can make a proof-of-save *exist* through a private constructor and a factory, but it cannot make it *spent*, so nothing would stop me clearing the flag with the same token twice; Rust takes the value away when it is used, and that is the part Java has no equivalent for. In both cases the work does not vanish -- it moves from the compiler to my tests and my discipline. The reason to reach for Rust here is not that the editor is otherwise impossible, which it plainly is not, but that a more expressive type system settles more of the program's correctness before a single test runs.

## References and Notes

[^mustuse]: Rust's `#[must_use]` attribute and the lint behind the warning: <https://doc.rust-lang.org/reference/attributes/diagnostics.html#the-must_use-attribute>

[^borrow]: References and borrowing in Rust, including the rules the borrow checker enforces: <https://doc.rust-lang.org/book/ch04-02-references-and-borrowing.html>

[^typestate]: Cliff L. Biffle, "The Typestate Pattern in Rust," a thorough walk through encoding state into types: <https://cliffle.com/blog/rust-typestate/>

[^receipt]: This sketch is illustrative, not airtight. The `Saved` token is not bound to a particular document or path, so within the module that defines these methods you could still write to one file and clear a different document's flag. A rigorous version would tie the proof to the instance; the point here is only that the rule can be pushed into the type at all.

[^java]: Kotlin, on the same JVM, enforces null-safety in its type system, distinguishing `String` from `String?` and checking it at compile time, which closes the first gap. Java's sealed types with a pattern-matching `switch` give compile-time exhaustiveness over a closed set of cases -- the same "every case is handled" guarantee Rust's enums provide -- and it can even encode method-presence typestate, so it carries more behaviour than the body alone might suggest. What stays particular to Rust is linearity: a value that is consumed when it is used. The broader point, that the type system's power sets how far the line can move, is what holds.
