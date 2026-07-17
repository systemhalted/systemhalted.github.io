---
layout: post
title: "The 2D↔1D Problem in Text Editors"
date: 2026-07-17
categories:
- Technology
- Software Engineering
- Computer Science
tags:
- rust
- text-editors
- emacs
- gedit
- data-structures
- unicode
comments: true
description: Editors show a 2D grid but store text as a 1D sequence. How textr, gedit, and Emacs bridge the gap, and why the choice follows the buffer's data structure.
---

Open a file in any editor and you see a grid: rows of text, a cursor at "line 12, column 5." Move down and the cursor drops a row. The position is two-dimensional.

But the file underneath is not a grid. A text file is a one-dimensional sequence: a flat run of characters, `h e l l o \n w o r l d`, where the newline is a character that means "start drawing on the next row." The buffer that holds the document in memory is the same, a sequence you index with a single number.

So every editor lives with a permanent translation problem. This post looks at how a few of them solve it: a from-scratch Rust editor I'm building ([textr](https://github.com/systemhalted/textr)), the two it is modeled on (**gedit** and **Emacs**), and **VS Code** for a fourth point of comparison.

* TOC
{:toc}

## The impedance mismatch

Two coordinate systems, describing the same text:

- **Humans and screens think in 2D:** `(line, column)`.
- **Files and buffers store 1D:** a single offset into a sequence.

![A caret shown in a 2D character grid on the left and mapped by an arrow to its position in a 1D flat, indexed character sequence on the right](/assets/images/2026-07-17-2d-1d-grid.svg)
*Figure 1 — The same caret, two coordinate systems. `(line 1, column 1)` on the left is flat index `4` on the right. The mapping between them is the editor's job.*

Bridging those two systems correctly and cheaply is one of the basic jobs of a text editor. Get it wrong and the cursor lands mid-character in a UTF-8 sequence, or an insert meant for one place writes three lines away.

## Where it comes up in textr

This shows up in textr's `View`, the cursor model.[^textr] The cursor is stored the way a user thinks about it:

```rust
struct View { line: usize, column: usize, goal_column: usize }
```

That is a 2D coordinate. But the buffer, a [ropey](https://github.com/cessen/ropey) rope, has a strictly 1D editing API:

```rust
doc.insert(char_idx, text);   // one index
doc.remove(char_idx..end);    // one index
```

`insert` doesn't know what a "line" is. To insert a character *where the cursor is*, I have to convert `(line, column)` into a single flat index. That conversion is one function:

```rust
pub fn cursor_char_idx(&self, doc: &Document) -> usize {
    doc.line_to_char(self.line) + self.column
}
```

`line_to_char(line)` gives the flat index where that line *starts*; add `column` and you have the caret's absolute position in the whole document. It's tempting to think `column` already *is* the index — and on line 0 it is, because line 0 starts at 0. But look at `"ab\ncd"` with the caret on the `d`:

```text
             index:  0   1   2   3   4
             char:   a   b   \n  c   d
                                     ^
   (line 1, column 1)  ->  line_to_char(1) + 1  =  3 + 1  =  4
```

`column` is `1`, but the flat index is `4`. `column` is "where I am *on this line*"; the flat index is "where I am *in the file*." The rope only understands the second one. (The reverse exists too, `char_to_line(idx)`, for when you have a flat position, like a search hit or a mouse click, and need to find the right row.)

Both conversions are cheap on a rope: ropey documents `line_to_char` and `char_to_line` as *O(log n)* each, and the `+ column` is *O(1)*, so moving a cursor between the two coordinate systems runs in *O(log n)* whichever way it goes.[^ropes]

## Why not just pick one and be done?

The harder question is not *how* to convert but **which representation is the source of truth**, and how it survives edits. There are a handful of strategies:

1. **Store 2D, derive 1D on demand** *(textr's choice)*. Keep `(line, column)` canonical; compute the flat index whenever the buffer needs it. Never store the index — a stored index goes stale the instant text changes ahead of it. *Pro:* vertical movement is native (Up/Down, and the "goal column" that remembers your column as you glide over short lines, are 2D ideas). *Con:* every edit must update the 2D cursor by hand, and 2D positions need clamping.
2. **Store 1D, derive 2D on demand** *(Emacs's choice)*. Keep a single integer offset canonical; compute line and column only to display or move by rows. *Pro:* dead simple — a position is *one number*. *Con:* line and column now cost a computation you mitigate with caches.
3. **Store both, keep them in sync.** Fast reads either way, but now *two* things must be updated on *every* edit or they drift.
4. **Hand out position *objects*.** An "iterator" that internally carries both representations. Cheap to read either way — but typically **invalidated by edits**, so you can't hold one across a modification.
5. **Persistent marks.** The subtle problem with any raw offset: if I remember "position 487" and someone inserts 10 characters at the top of the file, 487 now points somewhere wrong. A **mark** is a position the buffer *itself* keeps updated as text moves around it.

The choice is not free-floating. It falls out of **what the buffer is made of**:

![Four buffer data structures — gap buffer, rope, B-tree, and piece table — each annotated with the operations it makes cheap and the coordinate it treats as canonical](/assets/images/2026-07-17-buffer-structures.svg)
*Figure 2 — The storage structure decides which coordinate is cheap, which in turn pushes the design toward 1D-canonical or 2D-canonical.*[^structures]

Strategies 4 and 5 are not hypothetical. gedit uses both: iterators for cheap reads and marks for persistence. Emacs uses markers (strategy 5) alongside its 1D point.

## How gedit does it: iterators over a tree, cursor-as-mark

gedit is built on GTK's `GtkTextView`/`GtkSourceView`, backed by a [`GtkTextBuffer`](https://docs.gtk.org/gtk4/class.TextBuffer.html).[^gtk] Internally that buffer isn't a flat array — it's a **tree** (a B-tree) that indexes lines and character/byte offsets, so it can answer "where does line N start?" and "what line is offset K on?" in roughly *O(log n)*. Both directions of our conversion are cheap by construction.

You never touch raw offsets directly. Instead you work with [`GtkTextIter`](https://docs.gtk.org/gtk4/struct.TextIter.html) — a small stack-allocated struct representing a position, obtained from *either* coordinate system:

```c
GtkTextIter iter;
gtk_text_buffer_get_iter_at_line_offset(buffer, &iter, line, column); // from 2D
gtk_text_buffer_get_iter_at_offset(buffer, &iter, char_offset);       // from 1D
```

And crucially, an iter carries *both* representations at once — you can ask it for its line (`gtk_text_iter_get_line`), its column (`gtk_text_iter_get_line_offset`), or its absolute char offset (`gtk_text_iter_get_offset`). The 2D↔1D conversion is baked *into the iterator*, powered by that tree. GTK's answer to "which is the source of truth?" is essentially **"neither — the tree makes both cheap."**

The catch: **a `GtkTextIter` is transient — invalidated the moment the buffer is modified.** So you don't store iters; you re-fetch them.

For positions that must *persist* across edits, GTK gives you [`GtkTextMark`](https://docs.gtk.org/gtk4/class.TextMark.html), a named position the buffer maintains automatically. gedit's cursor is a mark named `"insert"` (the selection's other end is `"selection_bound"`). To render the caret, gedit gets an iter at the `"insert"` mark and reads its line and column; to type a character, it inserts at that iter. The persistence problem (strategy 5) and the conversion problem (strategy 4) are handled by two separate abstractions.

![gedit editing the Markdown source of this post, with "Ln 5, Col 12" shown in the status bar](/assets/images/2026-07-17-gedit-statusbar.png)
*Figure 3 — gedit with this post's draft open. The status bar reads "Ln 5, Col 12", the 2D face of the `"insert"` mark.*

## How Emacs does it: point is a number, everything else is derived

Emacs comes at it from the opposite end. Its buffer is a classic **gap buffer** — one big array of characters with a movable gap where edits happen, which makes insertion and deletion *at the cursor* very cheap.[^emacs]

Position in Emacs is [**point**](https://www.gnu.org/software/emacs/manual/html_node/elisp/Point.html): a single integer, the character offset of the caret (1-based — `point-min` is 1; positions sit *between* characters). Point is 1D and canonical. Almost every primitive takes or returns a buffer position as a plain integer.

Line and column are **not stored** — they're computed when asked:

```elisp
(line-number-at-pos)   ; scan / caches to count newlines before point
(current-column)       ; scan back to line start, honoring tab-width and char widths
```

[`current-column`](https://www.gnu.org/software/emacs/manual/html_node/elisp/Columns.html) shows that "column" is subtler than a character count: Emacs makes a tab advance to the next tab stop and accounts for wide characters, so the *visual* column and the *character* column differ. (textr, for now, uses character columns, a documented simplification.)[^unicode]

Computing line numbers means scanning for newlines — *O(distance)* — so Emacs keeps caches to amortize it (line-number lookup on a multi-megabyte buffer is a real, historically-tuned concern). For persistence, Emacs has [**markers**](https://www.gnu.org/software/emacs/manual/html_node/elisp/Markers.html) — objects that hold a position and are automatically nudged as text is inserted or deleted before them, with an [insertion type](https://www.gnu.org/software/emacs/manual/html_node/elisp/Marker-Insertion-Types.html) that decides whether a marker sticks or advances when text lands exactly on it. Same idea as GTK's marks, different name.

Emacs also separates **character positions from byte positions** ([`position-bytes`](https://www.gnu.org/software/emacs/manual/html_node/elisp/Text-Representations.html)) in multibyte buffers, so ordinary code can index by character and never split a multibyte sequence, the same reason textr indexes by `char`, never by byte.

![Emacs editing the same Markdown source, with (12,4) shown in the mode line](/assets/images/2026-07-17-emacs-modeline.png)
*Figure 4 — Emacs with the same file open. The mode line reads `(12,4)`, the line and column derived from point.*

## How VS Code does it: a piece tree

VS Code reaches a similar place to textr from a different direction.[^vscode] Its buffer is a **piece tree**: a piece table whose pieces hang off a balanced red-black tree, where each node caches the text length and line-break count of its subtree, so a lookup by line or by offset walks the tree in roughly *O(log n)* instead of scanning. Its canonical position is 2D, like textr's — the editor keeps the cursor as a [`Position`](https://microsoft.github.io/monaco-editor/typedoc/interfaces/IPosition.html) of `lineNumber` and `column`, both 1-based, and the flat offset is derived on demand through `getOffsetAt` and its inverse `getPositionAt`. The reason for keeping 2D canonical differs from textr's, though: the whole editor API is written in terms of `Position`, so 2D is the natural currency for the interface, not because vertical movement is the hardest job.

One detail sets VS Code apart from the other three. It measures `column` and the offset in **UTF-16 code units**, not characters, so an emoji outside the Basic Multilingual Plane counts as two columns and a grapheme built from combining marks spans several units. textr, gedit, and Emacs all index by `char` (Unicode scalar values); VS Code indexes by UTF-16 unit, and the two do not agree on where a given column falls.

## Side by side

| | **textr** (Rust) | **gedit** (GTK/C) | **Emacs** (C/Elisp) | **VS Code** (Monaco/TS) |
|---|---|---|---|---|
| Buffer structure | rope (ropey) | B-tree (`GtkTextBTree`) | gap buffer | piece tree |
| Canonical position | **2D** `(line, column)` | a **mark**; read via iters | **1D** `point` (integer) | **2D** `Position` (line, column) |
| 2D → 1D | `line_to_char + col` — *O(log n)* | build a `GtkTextIter` — *O(log n)* | rare; `goto-line` scans | `getOffsetAt` — *O(log n)* |
| 1D → 2D | `char_to_line` — *O(log n)* | iter carries line + offset | `line-number-at-pos` — scan + cache | `getPositionAt` — *O(log n)* |
| Persist across edits | recompute from `(line,col)` | `GtkTextMark` | markers | tracked ranges |
| Indexing unit | chars | chars (bytes tracked too) | chars (bytes separate) | UTF-16 code units |

## The choice follows the data structure and the dominant operation

There is no universally correct answer, only trade-offs that fall out of two things: **what the buffer is good at**, and **which operation you do most**.

- Emacs's gap buffer makes *offsets* cheap and edits-at-point cheap, so 1D-canonical is the simplest choice; it pays for line and column with scans and caches.
- gedit's tree makes *both* directions cheap, so it can afford to hide the whole question behind iterators and lean on marks for persistence.
- textr's rope also makes both directions cheap (*O(log n)* either way), so the choice was free. I picked **2D-canonical** because the `View`'s busiest and hardest job is *vertical* movement with a goal column, which is a 2D idea. The representation matches the operation it does most.
- VS Code's piece tree makes both directions cheap like gedit's, and it too keeps a 2D `Position` canonical — but for a different reason than textr: its whole editor API speaks in positions, so 2D is a matter of interface rather than of any single dominant operation.

One point is easy to miss: a raw offset is only correct for one moment. Once the text changes ahead of it, an old index points to the wrong place. That is why converting on demand (textr) or letting the buffer maintain the position (marks and markers) is safer than storing the number and reusing it. textr avoids the problem today because it has a single cursor that updates itself; when it grows multiple cursors or collaborative editing, it will want marks too, for the same reason every editor eventually adopts them.

---

## Notes

- **`GtkTextIter` is a value, not a handle.** It's valid only until the next buffer mutation; treat it as a snapshot and re-fetch after any edit. Persistent positions are `GtkTextMark`s, not stored iters.
- **Marker insertion type** decides the tie-break: when text is inserted exactly *at* a marker, does the marker stay put or advance past the new text? Emacs lets you choose per-marker; it's the kind of detail that quietly determines whether your saved position feels "before" or "after" an edit.
- **Character vs byte positions** are different numbers in any multibyte buffer. textr indexes by `char` throughout and never does byte math (ropey also exposes byte-index methods; textr uses only the char ones) — which is why inserting a precomposed `'é'` (U+00E9: one `char`, two UTF-8 bytes) advances the cursor by exactly one column. A decomposed `'é'` (`e` + a combining accent) is two chars and would advance by two — so this assumes NFC-normalized input; char indexing is not grapheme indexing.
- **ropey's phantom trailing line.** A rope for `"a\nb\n"` reports *three* lines — `"a\n"`, `"b\n"`, and a final empty `""`. The caret may rest on that empty line but no further; textr's `line_len_chars` helper strips the trailing `\n` so "end of line" lands before it, not after.
- **"Column" is not "display column."** This post (and textr, today) uses *character* columns. A real editor's visible column has to account for tab stops and wide/zero-width characters — which is exactly what Emacs's `current-column` does and where grapheme-cluster segmentation (UAX #29) eventually comes in.
- **textr is a learning project** — a from-scratch [gedit](https://gedit-text-editor.org/) clone I'm building to learn Rust, with a headless, UI-agnostic core and thin frontends. The 2D↔1D bridge above is one small, load-bearing piece of its `View`.

## References

[^textr]: textr's source — the `View` cursor model in [`crates/core/src/view.rs`](https://github.com/systemhalted/textr/blob/main/crates/core/src/view.rs) and the rope wrappers in [`crates/core/src/document.rs`](https://github.com/systemhalted/textr/blob/main/crates/core/src/document.rs); org-flavored sibling editor [textr-org](https://github.com/systemhalted/textr-org).
[^ropes]: ropey [docs](https://docs.rs/ropey) (`line_to_char`, `char_to_line`, `len_chars`). On ropes generally: Boehm, Atkinson & Plass, *"Ropes: an Alternative to Strings"* (Software: Practice and Experience, 1995), [doi.org/10.1002/spe.4380251203](https://doi.org/10.1002/spe.4380251203); Raph Levien, *"Rope science"* (xi-editor notes), [xi-editor.io](https://xi-editor.io/docs/rope_science_00.html).
[^structures]: [Gap buffer](https://en.wikipedia.org/wiki/Gap_buffer) and [piece table](https://en.wikipedia.org/wiki/Piece_table) on Wikipedia; VS Code's *"Text Buffer Reimplementation"* (their **piece tree** — a piece table backed by a red-black tree): [code.visualstudio.com](https://code.visualstudio.com/blogs/2018/03/23/text-buffer-reimplementation).
[^gtk]: [gedit](https://gedit-text-editor.org/) · [source](https://gitlab.gnome.org/GNOME/gedit); the B-tree that powers `GtkTextBuffer`, [`gtktextbtree.c`](https://gitlab.gnome.org/GNOME/gtk/-/blob/main/gtk/gtktextbtree.c).
[^emacs]: Emacs [buffer internals — the gap](https://www.gnu.org/software/emacs/manual/html_node/elisp/Buffer-Internals.html); source at [git.savannah.gnu.org](https://git.savannah.gnu.org/cgit/emacs.git) (`src/buffer.h`, `src/insdel.c`, `src/marker.c`).
[^unicode]: [UAX #29, *Unicode Text Segmentation*](https://unicode.org/reports/tr29/) (grapheme clusters); Rust crates [`unicode-width`](https://docs.rs/unicode-width) (display width, UAX #11) and [`unicode-segmentation`](https://docs.rs/unicode-segmentation) (UAX #29).
[^vscode]: VS Code / Monaco — `Position` (`lineNumber`/`column`, 1-based) in [`position.ts`](https://github.com/microsoft/vscode/blob/main/src/vs/editor/common/core/position.ts) and the [`IPosition`](https://microsoft.github.io/monaco-editor/typedoc/interfaces/IPosition.html) typedoc; `getOffsetAt`/`getPositionAt` in [`model.ts`](https://github.com/microsoft/vscode/blob/main/src/vs/editor/common/model.ts); columns measured in UTF-16 code units per [`vscode.d.ts`](https://github.com/microsoft/vscode/blob/main/src/vscode-dts/vscode.d.ts).
