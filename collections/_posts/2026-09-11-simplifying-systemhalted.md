---
layout: post
title: "Simplifying SystemHalted.in"
date: 2026-09-11
categories:
  - Personal Essays
  - Technology
tags:
  - redesign
  - blogging
  - jekyll
  - ux
  - meta
description: "Why I simplified SystemHalted and made the writing the center of the site"
comments: true
---
SystemHalted has been around for a long time. Over the years, I kept adding things to it.

Search. Categories. Tags. Series. Featured posts. Reading controls. Theme controls. Keyboard shortcuts. A table of contents. Different ways to browse older posts.

Most of these additions made sense when I added them. Together, they started making the site feel busy.

So I decided to simplify it.

SystemHalted has hundreds of posts covering software engineering, computing systems, leadership, AI, and other subjects. I do not want to reduce that. The archive is one of the things I value most about the site.

The problem was not the amount of content. The problem was the interface around it. Too many things were asking for attention at the same time. A reader opening an article should mostly see the article. A reader opening the homepage should mostly see what I have written recently.

One feature on the old site was Focus Mode. The idea was to remove distractions and make an article easier to read. But that raised another question. Why should a reader need to enable Focus Mode? If Focus Mode is the better reading experience, perhaps that should simply be the normal experience. That became one of the main ideas behind the redesign.

The default interface should already feel focused.

Instead of adding another reading mode, I started removing the things that made the normal mode need one.

The main navigation is now deliberately small:

**Writing · Projects · Archive · About**

These are the four main things I expect someone to look for.

Writing is the main purpose of the site. Projects have a place because I also use SystemHalted to document and share things I build. Archive provides access to older work. About explains who is behind the site.

Search and theme switching still exist, but they do not need the same visual importance as the main navigation.

Recent posts are now mostly a date and a title.

```text
Sep 11   Why I Love Omarchy
Sep 03   GTIDs, Kafka Consumer Offsets, and Recovery Checkpoints
Aug 25   Resource Integrity Belongs to the Resource, Not the API
```

If the title is interesting, you can open it.

There is also a link to Kartavya Path, my writing on engineering leadership and management on LinkedIn.

The homepage does not need to expose the full structure of the site. That is what the archive is for. Categories, tags, series, search, and chronological browsing still exist, but that complexity now lives where someone expects to find it. The homepage is for what is new. The archive is for what is already there.

An article page should get to the article quickly.

Something like:

```text
Article title

25 August 2026 · 9 min read

The article begins...
```

A table of contents can still be useful for a long article, but it does not need to take over the top of every post. It can stay collapsed until someone needs it.

Related writing can also stay out of the way until the reader reaches the end. The article should remain the most important thing on an article page.

The visual design is changing too. The old design relied more on boxes, panels, badges, borders, and different interface components. The new design relies more on typography and spacing.

SystemHalted still has its visual identity: Nord-inspired colors, a distinctive wordmark, and its own typography. But color is now an accent rather than something every component needs. The hierarchy comes mostly from type size, typeface, spacing, alignment, and content order.

Projects are slightly different from articles. An article is something you read from beginning to end. A project is something you scan, compare, and perhaps visit. So the Projects page can have a little more structure than the Writing page.

One thing I have learned from this redesign is that simplifying a site does not always mean deleting features. Sometimes the right answer is to stop putting every feature in front of the reader. Search can exist without dominating the header. Categories can exist without appearing beside every title. Keyboard shortcuts can exist without needing a visible button. Dark mode can exist without a settings panel.

SystemHalted is a place where I write and publish things I build. The design should make that easier to see. So instead of asking what else I can add to the site, I am trying to ask a different question:

**What can I remove without making the site less useful?**

That question has been much more useful.
