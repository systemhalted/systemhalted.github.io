---
layout: post
title: AI Governance Needs Responsibility, Not Just Principles
date: 2026-08-21
categories:
- AI
- Politics & Governance
tags:
- ai
- law
- technology
- software
- opinion
comments: true
description: On AI ethics, software responsibility, collective intelligence, and why new technological rights need institutions that can actually enforce them.
---

Most AI ethics writing arrives at the same conclusion. Principles are easy to state and hard to put into practice.

The gap between stating a principle and enforcing it matters more than the wording of the principle. A company can say it values fairness, transparency, accountability, privacy, and human oversight, and it may mean it. But without a way to assign responsibility, test behavior, and enforce consequences, those statements do not constrain what the company does.

AI makes this problem harder for software. Traditional professional responsibility does not fit the way software is built. A doctor can be held responsible for a diagnosis because the decision is usually attributable to the doctor. Software rarely works that way. A product decision, data choice, architecture tradeoff, model behavior, design constraint, release deadline, and legal interpretation all combine before the system reaches a user.

So when an AI system harms someone, the question is not only who wrote the code. It is also:

- Who specified the behavior?
- Who selected the training data or evaluation data?
- Who approved the product risk?
- Who decided the human review was sufficient?
- Who monitored failures after release?
- Who had the power to stop deployment?

Sometimes there are no clear answers and that is why AI Governance becomes difficult. 

## Professionalism is not enough

One proposed answer is to treat [software engineers more like licensed professionals](/2026/07/21/review-software-malpractice-in-the-age-of-ai/). The idea has some merit. Software systems now shape medicine, finance, transport, hiring, speech, policing, and public administration. The people who build them often have less formal accountability than practitioners in older professions whose mistakes affect fewer people.

However, a Software is usually not produced by a single professional exercising independent judgment. The engineer may understand the technical risk but lack authority over the business requirement. The product leader may own the user experience but not understand what causes the model to fail. The data team may know the bias in the dataset but not own the release decision. The legal team may approve a disclosure that is formally defensible but of little practical use to users. 

Licensing individual engineers would not solve that allocation problem on its own. It may raise the baseline of competence, and it may give engineers a stronger basis for refusing reckless work, but AI responsibility has to be assigned at the system level. Accountability has to include the organization, not just the coder.

## Soft law needs enforcement

That is why proposals for AI governance bodies are worth taking seriously. A [global or international coordinating body](/2026/07/31/review-agile-ethical-legal-model-ai-robotics-governance/) for AI and robotics would not solve enforcement on its own. It would, however, consolidate the existing pieces of soft law: professional guidelines, research norms, insurance requirements, audit expectations, publication standards, procurement rules, and sector-specific regulation.

This matters because AI systems cross borders more easily than laws do. The GDPR gives people enforceable rights within the European Union, but many AI harms do not stay in one jurisdiction. A model may be trained in one country, deployed by a company in another, served through infrastructure in a third, and used on people who live everywhere.

Without institutions that connect principles to incentives, companies comply where enforcement exists and treat the rest as optional.

The useful governance question is therefore not what AI should value. We already have many plausible lists. It is which institutions can attach real costs to ignoring those values.

## Collective intelligence has limits

Collective intelligence adds another complication. [Crowds can outperform individuals](/2026/08/14/review-studying-wisdom-of-crowds-at-scale/). Aggregated judgment can be more accurate and more stable than the judgment of any one participant. This holds in markets, elections, forecasts, open-source communities, and scientific review.

But crowds also herd. Social influence can make a group less accurate when people stop contributing independent judgment and start copying visible signals. Once that happens, the group amplifies a shared signal instead of aggregating independent ones.

This matters for AI governance because many modern systems are built out of feedback loops. Users rate content, models learn from users, recommender systems shape what users see, users respond to what was recommended, and the next version of the system absorbs the pattern. The crowd is part of the system rather than an external check on it.

So the question is not whether collective intelligence is good or bad. It is whether the system preserves enough independent signal for aggregation to work, and whether it can detect when influence has collapsed into herding.

## Technology reveals rights

Technology also changes which rights become practically important.

The right to be forgotten, the right to public anonymity, and the right to disconnect are useful examples. These rights did not become meaningful because human interests changed. People always had interests in privacy, dignity, rest, and control over reputation. What changed was the power technology put in others' hands.

Search engines, social networks, cheap storage, facial recognition, workplace messaging, and always-on devices shifted that power. One person, company, or state can now remember, locate, classify, and interrupt another person at a scale that older social norms were not built to handle. The underlying interest existed earlier, but the corresponding duty became visible only when technology made the imbalance large enough to matter.

That is the argument for treating some rights as ["revealed"](/2026/08/07/review-how-technological-advances-can-reveal-rights/) by technology. These interests are not new; however, the imbalance of power that makes them urgent certainly is.

## The actual work

AI governance will not be solved by choosing between ethics, law, or engineering. It needs all three.

Engineering provides tests, audits, monitoring, incident response, system design, and evidence. Law provides duties, remedies, procedures, and consequences. Ethics provides a way to describe what is at stake before the law addresses it.

The practical work is to connect them:

- Turn principles into concrete release criteria.
- Treat datasets, prompts, models, and evaluations as governed artifacts.
- Make responsibility traceable across product, engineering, data, legal, and leadership.
- Preserve independent human judgment where collective intelligence is being used.
- Recognize new technological rights before harm becomes normalized.
- Build institutions that make serious AI failures visible, attributable, and costly.

The test of AI governance is not whether an organization can write a responsible AI policy. It is whether, when the system fails, the organization can say who was responsible for knowing this could happen and what power that person had to prevent it. An organization that cannot answer has a policy, not governance.

## References

Danny Tobey, "Software Malpractice in the Age of AI: A Guide for the Wary Tech Company", AIES 2018.

Wendell Wallach and Gary E. Marchant, "An Agile Ethical/Legal Model for the International and National Governance of AI and Robotics", AIES 2018.

Camelia Simoiu, Chiraag Sumanth, Alok Mysore, and Sharad Goel, "Studying the Wisdom of Crowds at Scale", HCOMP 2019.

Jack Parker and David Danks, "How Technological Advances Can Reveal Rights", AIES 2019.
