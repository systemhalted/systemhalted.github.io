---
layout: post
title: "Where Am I? The 2D↔1D Problem at the Heart of Every Text Editor"
date: 2026-07-16
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
description: Editors show you a 2D grid but store text as a 1D sequence. How textr, gedit, and Emacs bridge the gap — and why the choice follows the buffer's data structure.
---

Open a file in any editor and you see a **grid**: rows of text, a cursor blinking at "line 12, column 5." Move down, and the cursor drops a row. It's a two-dimensional world.

But the computer underneath sees no grid. A text file is a **one-dimensional sequence** — a flat run of characters, `h e l l o \n w o r l d`, where the newline is just a character that happens to mean "start drawing on the next row." The buffer that holds your document in memory is the same: a sequence you index with a *single* number.

So every editor lives with a permanent translation problem, and this post is about how three of them solve it — a from-scratch Rust editor I'm building ([textr](https://github.com/systemhalted/textr)), plus the two it's modeled on: **gedit** and **Emacs**.

* TOC
{:toc}

## The impedance mismatch

Two coordinate systems, describing the same text:

- **Humans and screens think in 2D:** `(line, column)`.
- **Files and buffers store 1D:** a single offset into a sequence.

![A caret shown in a 2D character grid on the left and mapped by an arrow to its position in a 1D flat, indexed character sequence on the right](/assets/images/2026-07-16-2d-1d-grid.svg)
*Figure 1 — The same caret, two coordinate systems. `(line 1, column 1)` on the left is flat index `4` on the right. The editor's job is the arrow.*

Bridging those two systems, correctly and cheaply, is one of the quiet foundations of a text editor. Get it wrong and your cursor lands mid-character in a UTF-8 sequence, or your "insert here" writes three lines away.

## The moment it bit me in textr

I hit this building textr's `View` — the cursor model. The cursor is stored the way a user thinks about it:

```rust
struct View { line: usize, column: usize, goal_column: usize }
```

That's a 2D coordinate. But the buffer — a [ropey](https://github.com/cessen/ropey) rope — has a resolutely 1D editing API:

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

`column` is `1`, but the flat index is `4`. `column` is "where I am *on this line*"; the flat index is "where I am *in the file*." The rope only understands the second one. (The reverse exists too — `char_to_line(idx)` — for when you have a flat position, like a search hit or a mouse click, and need to light up the right row.)

## Why not just pick one and be done?

The deep question isn't *how* to convert — it's **which representation is the source of truth**, and how you survive edits. There are a handful of strategies, and every serious editor is a point in this space:

1. **Store 2D, derive 1D on demand** *(textr's choice)*. Keep `(line, column)` canonical; compute the flat index whenever the buffer needs it. Never store the index — a stored index goes stale the instant text changes ahead of it. *Pro:* vertical movement is native (Up/Down, and the "goal column" that remembers your column as you glide over short lines, are 2D ideas). *Con:* every edit must update the 2D cursor by hand, and 2D positions need clamping.
2. **Store 1D, derive 2D on demand** *(Emacs's choice)*. Keep a single integer offset canonical; compute line and column only to display or move by rows. *Pro:* dead simple — a position is *one number*. *Con:* line and column now cost a computation you mitigate with caches.
3. **Store both, keep them in sync.** Fast reads either way — and a standing invitation to bugs, because now *two* things must be updated on *every* edit or they drift.
4. **Hand out position *objects*.** An "iterator" that internally carries both representations. Cheap to read either way — but typically **invalidated by edits**, so you can't hold one across a modification.
5. **Persistent marks.** The subtle problem with any raw offset: if I remember "position 487" and someone inserts 10 characters at the top of the file, 487 now points somewhere wrong. A **mark** is a position the buffer *itself* keeps updated as text moves around it.

And the choice isn't free-floating — it falls out of **what your buffer is made of**:

![Four buffer data structures — gap buffer, rope, B-tree, and piece table — each annotated with the operations it makes cheap and the coordinate it treats as canonical](/assets/images/2026-07-16-buffer-structures.svg)
*Figure 2 — The storage structure decides which coordinate is cheap, which in turn nudges the whole design toward 1D-canonical or 2D-canonical.*

Strategies 4 and 5 aren't hypothetical. They're exactly how the two editors textr is modeled on do it.

## How gedit does it: iterators over a tree, cursor-as-mark

gedit is built on GTK's `GtkTextView`/`GtkSourceView`, backed by a [`GtkTextBuffer`](https://docs.gtk.org/gtk4/class.TextBuffer.html). Internally that buffer isn't a flat array — it's a **tree** (a B-tree) that indexes lines and character/byte offsets, so it can answer "where does line N start?" and "what line is offset K on?" in roughly *O(log n)*. Both directions of our conversion are cheap by construction.

You never touch raw offsets directly. Instead you work with [`GtkTextIter`](https://docs.gtk.org/gtk4/struct.TextIter.html) — a small stack-allocated struct representing a position, obtained from *either* coordinate system:

```c
GtkTextIter iter;
gtk_text_buffer_get_iter_at_line_offset(buffer, &iter, line, column); // from 2D
gtk_text_buffer_get_iter_at_offset(buffer, &iter, char_offset);       // from 1D
```

And crucially, an iter carries *both* representations at once — you can ask it for its line (`gtk_text_iter_get_line`), its column (`gtk_text_iter_get_line_offset`), or its absolute char offset (`gtk_text_iter_get_offset`). The 2D↔1D conversion is baked *into the iterator*, powered by that tree. GTK's answer to "which is the source of truth?" is essentially **"neither — the tree makes both cheap."**

The catch: **a `GtkTextIter` is transient — invalidated the moment the buffer is modified.** So you don't store iters; you re-fetch them.

For positions that must *persist* across edits, GTK gives you [`GtkTextMark`](https://docs.gtk.org/gtk4/class.TextMark.html) — a named position the buffer maintains automatically. And here's the elegant part: **gedit's cursor is literally a mark named `"insert"`** (the selection's other end is `"selection_bound"`). To render the caret, gedit gets an iter at the `"insert"` mark and reads its line/column; to type a character, it inserts at that iter. The persistence problem (strategy 5) and the conversion problem (strategy 4) are solved by two cooperating abstractions.

> **Figure — TODO screenshot:** gedit's status bar showing `Ln 12, Col 5` (the 2D face of the `"insert"` mark). *Drop a PNG at `/assets/images/2026-07-16-gedit-statusbar.png` and replace this note.*

## How Emacs does it: point is a number, everything else is derived

Emacs comes at it from the opposite end. Its buffer is a classic **gap buffer** — one big array of characters with a movable gap where edits happen, which makes insertion and deletion *at the cursor* very cheap.

Position in Emacs is [**point**](https://www.gnu.org/software/emacs/manual/html_node/elisp/Point.html): a single integer, the character offset of the caret (1-based — `point-min` is 1; positions sit *between* characters). Point is 1D and unapologetically canonical. Almost every primitive takes or returns a buffer position as a plain integer.

Line and column are **not stored** — they're computed when asked:

```elisp
(line-number-at-pos)   ; scan / caches to count newlines before point
(current-column)       ; scan back to line start, honoring tab-width and char widths
```

[`current-column`](https://www.gnu.org/software/emacs/manual/html_node/elisp/Columns.html) is a nice reminder that "column" is subtler than a character count: Emacs makes a tab advance to the next tab stop and accounts for wide characters, so the *visual* column and the *character* column differ. (textr, for now, punts on this and uses character columns — a documented simplification.)

Computing line numbers means scanning for newlines — *O(distance)* — so Emacs keeps caches to amortize it (line-number lookup on a multi-megabyte buffer is a real, historically-tuned concern). For persistence, Emacs has [**markers**](https://www.gnu.org/software/emacs/manual/html_node/elisp/Markers.html) — objects that hold a position and are automatically nudged as text is inserted or deleted before them, with an [insertion type](https://www.gnu.org/software/emacs/manual/html_node/elisp/Marker-Insertion-Types.html) that decides whether a marker sticks or advances when text lands exactly on it. Same idea as GTK's marks, different name.

One more Emacs wrinkle that echoes textr's Unicode care: Emacs separates **character positions from byte positions** ([`position-bytes`](https://www.gnu.org/software/emacs/manual/html_node/elisp/Text-Representations.html)) in multibyte buffers, precisely so ordinary code can index by character and never split a multibyte sequence — the same reason ropey (and textr) index by `char`, never by byte.

> **Figure — TODO screenshot:** Emacs's mode line showing `(12,4)` from `line-number-mode`/`column-number-mode`. *Drop a PNG at `/assets/images/2026-07-16-emacs-modeline.png` and replace this note.*

## Side by side

| | **textr** (Rust) | **gedit** (GTK/C) | **Emacs** (C/Elisp) |
|---|---|---|---|
| Buffer structure | rope (ropey) | B-tree (`GtkTextBTree`) | gap buffer |
| Canonical position | **2D** `(line, column)` | a **mark**; read via iters | **1D** `point` (integer) |
| 2D → 1D | `line_to_char + col` — *O(log n)* | build a `GtkTextIter` — *O(log n)* | rare; `goto-line` scans |
| 1D → 2D | `char_to_line` — *O(log n)* | iter carries line + offset | `line-number-at-pos` — scan + cache |
| Persist across edits | recompute from `(line,col)` | `GtkTextMark` | markers |
| Indexing unit | chars | chars (bytes tracked too) | chars (bytes separate) |

## The takeaway: the choice follows the data structure and the dominant operation

There's no universally correct answer — only trade-offs that fall out of two things: **what your buffer is good at**, and **which operation you do most.**

- Emacs's gap buffer makes *offsets* the natural currency and edits-at-point cheap, so 1D-canonical is the path of least resistance; it pays for line/column in scans-plus-caches.
- gedit's tree makes *both* directions cheap, so it can afford to hide the whole question behind iterators and lean on marks for persistence.
- textr's rope also makes both directions cheap (*O(log n)* either way), so the choice was genuinely free — and I picked **2D-canonical** because the `View`'s busiest, trickiest job is *vertical* movement with a goal column, which is a 2D idea through and through. Let the representation match the operation you sweat over.

And the piece that's easy to miss until it bites you: **a raw offset is a fact about a moment in time.** The instant the text changes, yesterday's index is a lie. That's why "convert on demand" (textr) or "let the buffer maintain the position" (marks and markers) beat "store the number and hope." textr sidesteps it today because there's a single cursor that updates itself — but the day it grows multiple cursors or collaborative editing, it'll want marks too, and learn the lesson every editor eventually does: *don't remember where something was; remember how to ask where it is now.*

---

## References

**textr (the code behind this post)**
- Repository: [github.com/systemhalted/textr](https://github.com/systemhalted/textr)
- The bridge — `cursor_char_idx` and the `View` cursor model: [`crates/core/src/view.rs`](https://github.com/systemhalted/textr/blob/main/crates/core/src/view.rs)
- The rope wrappers (`line_to_char`, `char_to_line`, `char_count`): [`crates/core/src/document.rs`](https://github.com/systemhalted/textr/blob/main/crates/core/src/document.rs)
- Org-flavored sibling editor: [github.com/systemhalted/textr-org](https://github.com/systemhalted/textr-org)

**Ropes**
- ropey crate — source [github.com/cessen/ropey](https://github.com/cessen/ropey), docs [docs.rs/ropey](https://docs.rs/ropey) (see `line_to_char`, `char_to_line`, `len_chars`)
- Boehm, Atkinson & Plass, *"Ropes: an Alternative to Strings"* (Software: Practice and Experience, 1995): [doi.org/10.1002/spe.4380251203](https://doi.org/10.1002/spe.4380251203)
- Raph Levien, *"Rope science"* (the xi-editor notes on rope-based editing, metrics, and line indexing): [xi-editor.io/docs/rope_science_00.html](https://xi-editor.io/docs/rope_science_00.html)

**Other buffer structures**
- Gap buffer: [en.wikipedia.org/wiki/Gap_buffer](https://en.wikipedia.org/wiki/Gap_buffer)
- Piece table: [en.wikipedia.org/wiki/Piece_table](https://en.wikipedia.org/wiki/Piece_table), and VS Code's *"Text Buffer Reimplementation"*: [code.visualstudio.com/blogs/2018/03/23/text-buffer-reimplementation](https://code.visualstudio.com/blogs/2018/03/23/text-buffer-reimplementation)

**gedit / GTK**
- gedit: [gedit-text-editor.org](https://gedit-text-editor.org/) · source [gitlab.gnome.org/GNOME/gedit](https://gitlab.gnome.org/GNOME/gedit)
- `GtkTextBuffer`: [docs.gtk.org/gtk4/class.TextBuffer.html](https://docs.gtk.org/gtk4/class.TextBuffer.html)
- `GtkTextIter` (note the invalidation-on-edit contract): [docs.gtk.org/gtk4/struct.TextIter.html](https://docs.gtk.org/gtk4/struct.TextIter.html)
- `GtkTextMark`: [docs.gtk.org/gtk4/class.TextMark.html](https://docs.gtk.org/gtk4/class.TextMark.html)
- The B-tree that powers it — `gtktextbtree.c`: [gitlab.gnome.org/GNOME/gtk/-/blob/main/gtk/gtktextbtree.c](https://gitlab.gnome.org/GNOME/gtk/-/blob/main/gtk/gtktextbtree.c)

**Emacs**
- Point: [gnu.org/…/elisp/Point.html](https://www.gnu.org/software/emacs/manual/html_node/elisp/Point.html)
- Markers & insertion types: [Markers.html](https://www.gnu.org/software/emacs/manual/html_node/elisp/Markers.html), [Marker-Insertion-Types.html](https://www.gnu.org/software/emacs/manual/html_node/elisp/Marker-Insertion-Types.html)
- Columns (`current-column`): [Columns.html](https://www.gnu.org/software/emacs/manual/html_node/elisp/Columns.html)
- Char vs byte positions: [Text-Representations.html](https://www.gnu.org/software/emacs/manual/html_node/elisp/Text-Representations.html)
- Buffer internals (the gap): [Buffer-Internals.html](https://www.gnu.org/software/emacs/manual/html_node/elisp/Buffer-Internals.html) · source [git.savannah.gnu.org/cgit/emacs.git](https://git.savannah.gnu.org/cgit/emacs.git) (`src/buffer.h`, `src/insdel.c`, `src/marker.c`)

**Unicode & columns**
- UAX #29, *Unicode Text Segmentation* (grapheme clusters): [unicode.org/reports/tr29](https://unicode.org/reports/tr29/)
- `unicode-width`: [docs.rs/unicode-width](https://docs.rs/unicode-width) · `unicode-segmentation`: [docs.rs/unicode-segmentation](https://docs.rs/unicode-segmentation)

## Notes

- **`GtkTextIter` is a value, not a handle.** It's valid only until the next buffer mutation; treat it as a snapshot and re-fetch after any edit. Persistent positions are `GtkTextMark`s, not stored iters.
- **Marker insertion type** decides the tie-break: when text is inserted exactly *at* a marker, does the marker stay put or advance past the new text? Emacs lets you choose per-marker; it's the kind of detail that quietly determines whether your saved position feels "before" or "after" an edit.
- **Character vs byte positions** are different numbers in any multibyte buffer. textr and ropey index by `char` throughout and never do byte math — which is why inserting `'é'` (two UTF-8 bytes) advances the cursor by exactly one column with no special-casing.
- **ropey's phantom trailing line.** A rope for `"a\nb\n"` reports *three* lines — `"a\n"`, `"b\n"`, and a final empty `""`. The caret may rest on that empty line but no further; `line_len_chars` strips the trailing `\n` so "end of line" lands before it, not after.
- **"Column" is not "display column."** This post (and textr, today) uses *character* columns. A real editor's visible column has to account for tab stops and wide/zero-width characters — which is exactly what Emacs's `current-column` does and where grapheme-cluster segmentation (UAX #29) eventually comes in.
- **textr is a learning project** — a from-scratch [gedit](https://gedit-text-editor.org/) clone I'm building to learn Rust, with a headless, UI-agnostic core and thin frontends. The 2D↔1D bridge above is one small, load-bearing piece of its `View`.
