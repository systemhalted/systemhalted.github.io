---
layout: post
title: "Review: Software Malpractice in the Age of AI"
date: 2026-07-21
categories:
- Article Review
- AI
tags:
- ai
- law
- software
- article-review
- opinion
comments: true
description: A review of Danny Tobey's argument that AI makes software malpractice harder to avoid, and why responsibility in software cannot be modeled exactly like medical malpractice.
---

Danny Tobey's "Software Malpractice in the Age of AI" makes a useful and uncomfortable argument: as software becomes more consequential, the software industry cannot keep pretending that professional responsibility belongs only to older professions such as medicine, law, accounting, and nursing.

The paper surveys legal precedent around software, especially in medicine, and argues that the rise of AI weakens one of the assumptions that has historically protected software vendors from malpractice-style liability. That assumption is that human professionals remain the real decision makers, while software merely assists them.

For ordinary clinical decision-support systems, that line may seem plausible. A doctor reviews the output, applies professional judgment, and accepts or rejects the recommendation. But with narrow AI systems that develop deep expertise in a domain, the relationship becomes less clean. If a system produces a recommendation that a human reviewer cannot meaningfully audit, then "human oversight" can become more procedural than real.

That is the paper's strongest point. AI makes it harder to rely on the fiction that a human independently reviewed the basis for a software recommendation.

## Where I agree

I agree with the paper's central concern. Technology companies and software professionals should not be immune from responsibility simply because the harm is mediated through code.

Software now helps decide medical treatment, credit access, hiring, public benefits, fraud detection, insurance pricing, and many other areas where mistakes can alter a person's life. When systems operate at that level of consequence, the industry needs a more serious account of duty, care, review, and accountability.

The paper is also right to look at professional malpractice as a useful comparison. Older professions have already built ideas around competence, fiduciary responsibility, licensing, insurance, standards of care, and disciplinary consequences. Software does not need to copy that structure blindly, but it should learn from it.

## Where the analogy weakens

The main weakness is that the doctor-software-engineer analogy does not map cleanly.

A doctor usually owns the professional act of diagnosis or treatment. Even when the doctor consults peers, the final professional decision is attributable to that doctor. Software is rarely produced that way.

A deployed AI product is usually the result of many decisions:

- Product defines the user problem and desired behavior.
- Data teams choose or prepare datasets.
- Engineers implement the system.
- Model teams tune behavior.
- Designers shape how users interpret the output.
- Legal and compliance teams approve risk language.
- Executives decide whether the product ships.

If harm occurs, it may be impossible or unfair to assign responsibility only to the individual engineer who wrote part of the implementation. The engineer may have seen the risk but lacked authority to block release. Or the risk may have emerged from a product decision, data limitation, or business constraint outside the engineer's control.

That does not mean nobody is responsible. It means software responsibility has to be organizational, not merely individual.

## What the paper leaves open

The paper is valuable as a survey and warning, but it does less to explain how responsibility should actually be assigned inside software organizations.

Several questions need more work:

- What would a software "standard of care" look like for AI systems?
- Which duties should belong to engineers, product leaders, data scientists, executives, and companies?
- Should licensing apply to all software engineers, or only to those working in high-risk domains?
- How should certifications, professional societies, or bodies such as IEEE shape enforceable practice?
- How do existing frameworks such as GDPR or human-rights declarations become operational inside product development?

The strongest version of this argument would move from analogy to mechanism. It would define what competent AI development requires, what evidence must be produced before deployment, and who is accountable when that evidence is ignored.

## Bottom line

"Software Malpractice in the Age of AI" is worth reading because it names a real gap: AI systems are becoming professionally consequential without the professional accountability structure that older high-stakes domains developed over time.

But the solution cannot simply be "treat software engineers like doctors." Software is too collaborative, too organizational, and too entangled with product and business incentives for that analogy to carry the whole burden.

AI malpractice, if the term is to mean anything useful, has to attach responsibility to the system of production. That includes the engineer, but it also includes the company that creates the incentives, approves the risks, and profits from the deployment.

## Reference

Danny Tobey, "Software Malpractice in the Age of AI: A Guide for the Wary Tech Company", AIES 2018.
