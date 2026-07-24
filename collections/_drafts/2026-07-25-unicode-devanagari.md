---
layout: post
title: "Hindi Is More Interesting Than ASCII: How Devanagari Actually Works in Unicode"
date: 2026-07-25
categories:
- Computer Science
tags:
- unicode
- devanagari
comments: true
description: This post looks at how Devanagari actually works in Unicode
---

Why do we need Unicode[^unicode]? The answer usually is that ASCII[^ascii] was too small. It could represent English but not the thousands of characters used by other writing systems. Unicode fixed this by assigning every character a unique number called a code point[^codepoint].

```
A    U+0041
a    U+0061
अ    U+0905
क    U+0915
```

The explanation is correct to an extent; however it is not precise. It suggests that Unicode is a very large ASCII table: ASCII has a number for `A`, so Unicode has a number for `अ`; ASCII has a number for `B`, so Unicode has a number for `क`. From there it is a short step to assuming that every Hindi character on the screen has its own Unicode number. It does not and looking at how Devanagari[^devanagari] actually works in Unicode gives us a way to look into the workings of Unicode. 

## Start with क

The Devanagari letter क has the code point:

```
U+0915    DEVANAGARI LETTER KA
```

So far the ASCII model holds. One letter, one number.

Now consider कि.

A Hindi reader sees this as a single syllabic unit, and the vowel sign ि[^matra] appears visually to the *left* of the consonant. It would be reasonable to assume the computer stores it in that order. It does not. The stored sequence is:

```
क    U+0915    DEVANAGARI LETTER KA
ि    U+093F    DEVANAGARI VOWEL SIGN I
```

That is, `U+0915 U+093F` -- consonant first, vowel sign second. If you have ever typed in Hindi on your iPhone, that is the order you type as well. 

Something happened between the sequence in memory and the pixels on the display. That something is text shaping[^shaping].

## Unicode describes logical text, not pixels

Unicode encodes characters and their logical order. It does not specify the shapes that end up on screen. The path from one to the other runs roughly like this:

```
code points → encoded bytes → shaping engine → glyph selection → pixels
```

For Latin text most of this machinery is easy to overlook. `cat` is stored as `c`, `a`, `t` and displayed as `c a t`. Stored characters and displayed glyphs[^glyph] look one-to-one.

Devanagari breaks that assumption immediately.

## क्ष

The conjunct[^conjunct] क्ष looks like one character. Unicode does not encode it as one. It is:

```
क    U+0915    DEVANAGARI LETTER KA
्    U+094D    DEVANAGARI SIGN VIRAMA
ष    U+0937    DEVANAGARI LETTER SSA
```

The virama[^virama] is the key element. It suppresses the inherent `a` vowel[^inherentvowel] that a Devanagari consonant letter carries by default, which is what allows two consonants to join. When the shaping engine sees `consonant + virama + consonant`, it applies the font's conjunct rules and may produce a single ligature glyph, or a half-form[^halfform] of the first consonant followed by the full second consonant, depending on the font. Both are correct renderings of the same three code points.

So one thing on screen, three code points underneath.

## Five terms that are not synonyms

Once you accept that, the vocabulary has to get more precise. Five terms get used interchangeably and should not be:

**Code point.** A number in the Unicode code space, from `U+0000` to `U+10FFFF`. `U+0915` is a code point.

**Character.** An abstract textual element. क is a character, represented by the code point `U+0915`. Unicode itself uses "character" loosely, which is part of the problem.

**Code unit.** The unit of the encoding form you chose. UTF-8[^utf] has 8-bit code units; a Devanagari code point takes three of them. UTF-16 has 16-bit code units, and nearly[^nearly] every Devanagari code point fits in one, because the main block sits in the Basic Multilingual Plane[^bmp]. UTF-32 has 32-bit code units, one per code point.

**Grapheme cluster.** A user-perceived character, defined by the segmentation rules in UAX #29[^uax29]. This is the closest thing to what a reader would call "one character."

**Glyph.** A shape in a font. Glyphs are what a font actually contains, and the mapping from characters to glyphs is many-to-many.

Almost every bug in this area comes from a program using one of these when it meant another.

## Counting the same string five ways

Here are the three examples measured against each definition. All Devanagari code points encode as three bytes in UTF-8 and one code unit in UTF-16.

| String | UTF-8 bytes | UTF-16 units | Code points | Clusters (pre-15.1) | Clusters (15.1+) |
|---|---|---|---|---|---|
| कि | 6 | 2 | 2 | 1 | 1 |
| क्ष | 9 | 3 | 3 | 2 | 1 |
| श्री | 12 | 4 | 4 | 2 | 1 |
| हिन्दी | 18 | 6 | 6 | 3 | 2 |
| नमस्ते | 18 | 6 | 6 | 4 | 3 |
| स्त्र्य | 21 | 7 | 7 | 4 | 1 |
| क्षत्रिय | 24 | 8 | 8 | 5 | 3 |

नमस्ते decomposes as:

```
न    U+0928    DEVANAGARI LETTER NA
म    U+092E    DEVANAGARI LETTER MA
स    U+0938    DEVANAGARI LETTER SA
्    U+094D    DEVANAGARI SIGN VIRAMA
त    U+0924    DEVANAGARI LETTER TA
े    U+0947    DEVANAGARI VOWEL SIGN E
```

Six code points. A Hindi reader would say three units: न, म, स्ते. Depending on your runtime, a grapheme segmenter will tell you three or four.

## The cluster count depends on your runtime, not your code

Before Unicode 15.1, the extended grapheme cluster rules broke *after* a virama. क्ष counted as two clusters, नमस्ते as four. Unicode 15.1 added rule GB9c[^gb9c], which uses the new `Indic_Conjunct_Break`[^incb] property to hold `consonant + linker + consonant` together. Devanagari virama has `InCB=Linker`, so under 15.1 क्ष is one cluster.

This is not hypothetical. Here is `java.text.BreakIterator`[^breakiterator] on JDK 21:

```
हिन्दी     [हि][न्][दी]              3 clusters
क्षत्रिय   [क्][ष][त्][रि][य]        5 clusters
नमस्ते     [न][म][स्][ते]            4 clusters
कि         [कि]                      1 cluster
क्ष        [क्][ष]                   2 clusters
```

Every one of those is the pre-15.1 answer. The conjuncts split at the virama.

There are two things going on here. First, JDK 21 ships Unicode 15.0 character data, not 15.1 -- you can confirm this without documentation by probing a marker code point:

```java
Character.isDefined(0x11B00)   // true  -- Devanagari Extended-A, Unicode 15.0
Character.isDefined(0x2EBF0)   // false -- CJK Ext-I, Unicode 15.1
```

Second, and more important, `java.text.BreakIterator` carries its own segmentation rule data that is largely independent of the character tables. Upgrading the JDK does not reliably get you GB9c. For 15.1 behaviour in Java you need ICU4J's[^icu] `com.ibm.icu.text.BreakIterator`.

So the pre-15.1 column above is measured. The 15.1+ column is what the current rules specify. Which one your program produces is a property of the library you happened to link.

## What `length` actually returns

The draft note on this post suggested that Java, JavaScript and Python disagree about the length of Hindi text. They mostly do not, and the reason is worth understanding.

For नमस्ते:

```java
"नमस्ते".length()                      // 6   UTF-16 code units
"नमस्ते".codePointCount(0, 6)          // 6   code points
"नमस्ते".getBytes(UTF_8).length        // 18  bytes
```

```javascript
"नमस्ते".length                        // 6   UTF-16 code units
[..."नमस्ते"].length                   // 6   code points
```

```python
len("नमस्ते")                          # 6   code points
len("नमस्ते".encode())                 # 18  bytes
```

```go
len("नमस्ते")                          // 18  bytes
utf8.RuneCountInString("नमस्ते")       // 6   code points
```

```rust
"नमस्ते".len()                         // 18  bytes
"नमस्ते".chars().count()               // 6   code points
```

Java and JavaScript store strings as UTF-16 and report code units. Python stores code points and reports code points. Go and Rust store UTF-8 and report bytes. For Devanagari, the first three agree at 6, because every Devanagari code point is a single UTF-16 code unit.

The divergence between Java/JavaScript and Python shows up outside the BMP. For the single emoji `😀` (`U+1F600`), Java and JavaScript report 2, because it needs a surrogate pair; Python reports 1; Go and Rust report 4 bytes.

The more useful observation is that *none* of these numbers is 3, which is the number a Hindi reader would give for नमस्ते. Getting closer requires explicit grapheme segmentation:

```java
BreakIterator.getCharacterInstance()   // 4 on JDK 21 -- see above
```

```javascript
new Intl.Segmenter("hi", { granularity: "grapheme" })
```

```python
import regex
regex.findall(r"\X", "नमस्ते")
```

```rust
// unicode-segmentation crate
"नमस्ते".graphemes(true).count()
```

Even these depend on the ICU or Unicode data version, per the GB9c caveat above.

## Normalization: two ways to write the same letter

Devanagari also has a normalization problem. The letter क़ (`qa`) can be written two ways:

```
U+0958                    DEVANAGARI LETTER QA
U+0915 U+093C             KA + DEVANAGARI SIGN NUKTA
```

These are canonically equivalent[^canonequiv]. They must be treated as the same text by any conforming process, and they usually render identically. But they are different byte sequences, so `equals`, `==`, hash lookups, and database unique constraints will treat them as different unless the text is normalized first.

There is a trap here. `U+0958` through `U+095F` are on the Unicode composition exclusion list[^compexclusion]. NFC[^nfc] does not recompose them. Normalizing either form to NFC gives you `U+0915 U+093C`, the decomposed one. If you assumed NFC always produces the shortest sequence, this is a counterexample.

Normalization also reorders combining marks by canonical combining class[^ccc]. Nukta[^nukta] has `ccc=7`, virama has `ccc=9`, so a nukta typed after a virama gets reordered ahead of it:

```
as typed : U+0915 U+094D U+093C     क + virama + nukta
NFC      : U+0915 U+093C U+094D     क + nukta + virama
```

Two sequences that differ only in the order the user typed them collapse to one form.

The practical rule: normalize at your system boundaries -- on input, before storage, before comparison -- and pick one form, usually NFC.

## Sorting is a separate problem

Normalization fixes equality. It does not fix order, and binary comparison[^collation] gets Devanagari order wrong in a way that is easy to miss.

The reason is where the nukta letters sit in the block. क is `U+0915`, ख is `U+0916`, ह is `U+0939`. But क़ has its own precomposed code point at `U+0958`, past the end of the consonant range. Sort by code point and क़ lands after every basic consonant, including ह.

```
                              compareTo   Collator(hi)
क  vs ख                              -1            -1
क  vs का                             -1            -1
का vs कि                             -1            -1
क़  vs ख                              +1            -1
क़  vs क+़                            +1             0
ड़  vs ढ                              +1            -1
```

The first three pairs agree, which is why this bug survives casual testing. Compare a few basic letters and binary order looks fine. The nukta letters are where it breaks, and the last row is worse than wrong order: two canonically equivalent spellings of the same letter compare as unequal.

Sorting a word list makes it concrete. The same word क़लम, written once with `U+0958` and once with `U+0915 U+093C`:

```
String.compareTo        Collator(hi)
  कमल                     कमल
  कल                      कल
  क़लम   (U+0915…)         क़लम   (U+0958…)
  खत                      क़लम   (U+0915…)
  गाना                    खत
  क़लम   (U+0958…)         गाना
```

Binary order scatters the two spellings to positions three and six with unrelated words between them. The collator files them adjacent, both immediately after क.

One trap inside the fix. `Collator.getInstance(...).getDecomposition()` returns `NO_DECOMPOSITION` by default. The Hindi collator handles `U+0958` anyway, because the JDK ships real `hi` rules -- `Collator.getInstance(Locale.ROOT)` returns `+1` for that pair rather than `0`. Do not rely on the default. Set `CANONICAL_DECOMPOSITION` explicitly, and pick the locale deliberately.

## What the shaping engine does

Between code points and glyphs sits a shaper: HarfBuzz[^harfbuzz] on most Linux and web stacks, DirectWrite/Uniscribe on Windows, CoreText on Apple platforms. For Devanagari it runs a script-specific model that, roughly:

1. Splits the run into syllable clusters.
2. Identifies the base consonant of each cluster.
3. Applies OpenType[^opentype] features from the font -- `nukt`, `akhn`, `rphf`, `blwf`, `half`, `pstf`, `vatu`, `cjct` -- to form half-forms, conjuncts and below-base forms.
4. Reorders pre-base matras such as ि so they sit to the left of the base glyph.
5. Applies positioning features and produces final glyph IDs with offsets.

Step 4 is the answer to the कि puzzle from the start of the post. The reordering is a rendering operation, performed by the shaper, using rules that depend on the font. It never touches the stored text.

This separation is also why Unicode does not encode every conjunct. Devanagari can form a very large number of consonant combinations. Encoding each visible shape separately would merge two different questions -- *what text is this* and *how should this text look* -- into one, and would make the encoding dependent on typographic fashion. Unicode answers the first question. Fonts and shapers answer the second.

## Where this actually bites

The consequences are ordinary and frequent.

**Truncation.** Cutting a string at a fixed byte or code-unit offset can split a UTF-8 sequence, or split a cluster and leave a dangling virama or matra. Truncate on grapheme cluster boundaries, or at minimum on code point boundaries.

**Cursor movement and deletion.** Pressing backspace after typing क्ष should not leave क् behind. Editors need cluster-aware navigation. Note that for Indic scripts, the caret positions users expect are sometimes finer than grapheme cluster boundaries, which UAX #29 acknowledges as a legitimate tailoring.

**Length validation.** "Maximum 20 characters" needs a definition. Take the sentence भारत एक महान देश है। -- that is 52 UTF-8 bytes, 20 UTF-16 code units, 20 code points, 16 grapheme clusters, and five words. Five plausible answers, and a `varchar(20)` column accepts or rejects it depending on which one the database counts. PostgreSQL `varchar(n)` counts code points, MySQL `utf8mb4` counts characters, Oracle `VARCHAR2` counts bytes or characters depending on how the column was declared.

**Comparison and search.** Without normalization, canonically equivalent strings fail to match. Without a collator, sort order is wrong for the nukta letters. Substring search on code point offsets can match across a cluster boundary.

**Word segmentation.** `BreakIterator.getWordInstance` does not treat the danda `U+0964`[^danda] as a word boundary, so the last token of a Hindi sentence comes back as `है।` with the punctuation attached. Sentence-ending punctuation that is not a full stop needs handling you would not write for English.

**Reversal.** Reversing a string by code point turns नमस्ते into a sequence that no longer renders as valid text. Reverse by grapheme cluster or not at all.

**Regular expressions.** `.` matches a code point in most engines, not a cluster. Character classes written for Latin text do not carry over.

## The point

When we look at क्ष our eyes report one thing. The computer is handling three code points and nine bytes, and reports either one cluster or two depending on which segmentation library got linked. When we look at कि we see the vowel first, and it is stored second.

Neither representation is wrong. They are different layers of the same writing system. Unicode encodes the logical text, an encoding form turns it into bytes, a shaper interprets it, a font supplies the glyphs, and the renderer produces pixels. What appears on the screen is the end of that pipeline, not a picture of what is in memory.

ASCII made every layer coincide, so the pipeline was invisible and the mental model survived. Devanagari makes it impossible to ignore.

---

[^unicode]: A character encoding standard maintained by the Unicode Consortium, covering the writing systems of the world. Version 1.0 shipped in 1991; releases are now roughly annual. It defines both a repertoire of characters and a large set of per-character properties.

[^ascii]: American Standard Code for Information Interchange, 1963. Seven bits, 128 positions, of which 95 are printable. Enough for unaccented English and effectively nothing else.

[^codepoint]: The written form is `U+` followed by at least four hexadecimal digits, so `U+0915` is decimal 2325. The notation is fixed by the standard and is used regardless of how the value is stored in memory.

[^devanagari]: The script used to write Hindi, Marathi, Nepali, Sanskrit and others. It is an abugida[^abugida] rather than an alphabet, which is the root of most of what follows.

[^abugida]: A writing system in which each consonant letter carries an inherent vowel[^inherentvowel], modified or cancelled by attached marks, rather than one in which consonants and vowels are equal, independent letters. Devanagari, Bengali, Tamil, Thai and Ethiopic are abugidas. Latin, Greek and Cyrillic are alphabets.

[^matra]: A vowel sign, or *matra*, is a mark attached to a consonant to replace its inherent vowel[^inherentvowel]. Matras attach above, below, before or after the base consonant depending on which vowel they represent. `ि` is one of the ones that attaches before.

[^shaping]: Also called text layout. The stage that turns a sequence of characters into a sequence of positioned glyphs by applying the font's substitution and positioning rules. It is script-specific: Devanagari, Arabic and Latin take different code paths.

[^glyph]: A font contains glyphs, not characters. One character may map to several glyphs, several characters may map to one glyph, and the same character may map to different glyphs depending on its neighbours.

[^conjunct]: In Devanagari, a *samyuktakshar* -- two or more consonants written as a single joined form with no vowel between them, the vowel having been suppressed by a virama[^virama]. Hindi uses a few hundred in practice; the number that can be formed is far larger.

[^virama]: Called *halant* in Hindi. Written `्` and encoded at `U+094D`.

[^inherentvowel]: Every Devanagari consonant letter carries an implicit *a*. क alone reads as *ka*, not *k*. This is the defining property of an abugida[^abugida], and the reason a separate mark is needed to cancel it.

[^halfform]: A reduced form of a consonant used inside conjuncts[^conjunct], typically the full letter with its vertical stem removed. क् as a half-form joins directly to the letter that follows.

[^utf]: An encoding form specifies how a code point becomes bytes. UTF-8 uses one to four 8-bit units and dominates on disk and on the wire. UTF-16 uses one or two 16-bit units and is what Java, JavaScript, C# and the Windows API use in memory. UTF-32 uses one 32-bit unit per code point and is rare outside internal buffers.

[^nearly]: *Nearly* is an important distinction. Unicode 15.0 added Devanagari Extended-A at `U+11B00`–`U+11B5F`, ten characters for Vedic and Sanskrit editorial marks. Those are above `U+FFFF`, so they take a surrogate pair[^surrogate] in UTF-16 and four bytes in UTF-8. They are the only Devanagari characters where Java's `length()` and Python's `len()` disagree.

[^bmp]: The first 65,536 code points, `U+0000` to `U+FFFF`. Unicode has 17 planes; everything above the BMP is called supplementary. The split matters only for UTF-16[^utf], where supplementary characters need two code units instead of one.

[^surrogate]: A pair of code units drawn from `U+D800`–`U+DBFF` and `U+DC00`–`U+DFFF`, used together by UTF-16[^utf] to represent one supplementary code point[^bmp]. The halves are not valid characters on their own, which is why splitting a UTF-16 string at an arbitrary offset can produce something unencodable.

[^uax29]: Unicode Standard Annex #29, *Unicode Text Segmentation*. It specifies boundary rules for grapheme clusters, words and sentences, and explicitly permits implementations to tailor them per language.

[^gb9c]: Grapheme break rule 9c of UAX #29[^uax29], added in Unicode 15.1. The rules run GB1 through GB13; 9c was inserted specifically to stop Indic conjuncts[^conjunct] splitting, which they had done since the rules were first written.

[^incb]: A character property introduced alongside GB9c, with values `Consonant`, `Linker`, `Extend` and `None`. The virama[^virama] of Devanagari, Bengali, Gujarati, Malayalam, Oriya and Telugu is classified as `Linker`.

[^breakiterator]: The JDK's segmentation API, in `java.text`. It predates ICU[^icu] and ships its own rule tables, which is why its behaviour tracks the JDK release rather than the Unicode version of the character data.

[^icu]: International Components for Unicode, the reference implementation of most of the standard's algorithms, including the segmentation rules of UAX #29[^uax29] and the collation algorithm[^collation]. ICU4J is the Java build, ICU4C serves C and C++. Most platforms with correct Unicode behaviour have ICU somewhere underneath.

[^canonequiv]: Two sequences are canonically equivalent when the standard declares them to represent the same abstract text, and conforming software must not distinguish them. This is a stronger claim than "they look the same" and a weaker one than "they are the same bytes."

[^compexclusion]: A list in the standard of characters that have a canonical decomposition but must not be recomposed by NFC[^nfc]. It exists largely for compatibility with older national standards that encoded such characters directly.

[^nfc]: Unicode defines four normalization forms. NFD decomposes. NFC decomposes and then recomposes. All four map canonically equivalent[^canonequiv] sequences to the same output. NFKD and NFKC additionally fold compatibility differences such as ligatures and superscripts, and are lossy. NFC is the usual choice for storage and comparison.

[^ccc]: A numeric property from 0 to 254 that fixes the relative order of combining marks around a base character. Marks sharing a class keep the order they were typed in; marks with different classes are sorted into class order during normalization[^nfc].

[^nukta]: A dot written below a consonant, `U+093C`, that modifies its sound. It is used mainly for consonants borrowed from Persian and Arabic. Eight nukta combinations also have precomposed code points, all of them on the composition exclusion list[^compexclusion], which is the source of the trouble described here.

[^collation]: Collation is language-aware sorting. Binary comparison orders strings by numeric value, which reflects the order characters happened to be added to the standard rather than any language's alphabet. A collator also folds canonically equivalent[^canonequiv] sequences together, which binary comparison cannot. The Unicode Collation Algorithm is specified separately, in UTS #10.

[^harfbuzz]: The open-source shaping[^shaping] engine used by Chrome, Firefox, Android, GNOME and LibreOffice. DirectWrite and CoreText are the Microsoft and Apple equivalents.

[^opentype]: The font format, and the tag-based feature system inside it. Each four-letter tag names a substitution or positioning rule the shaper may apply. `cjct` forms conjuncts[^conjunct], `half` forms half-forms[^halfform], `rphf` handles the reph, and so on.

[^danda]: `U+0964`, the full stop of Devanagari and several other Indic scripts. `U+0965`, the double danda, marks a larger break -- historically the end of a verse.
