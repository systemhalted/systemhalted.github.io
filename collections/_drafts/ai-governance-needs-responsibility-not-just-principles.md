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

Most AI ethics writing ends up in the same place: principles are easy to state, and hard to make real.

That gap matters more than the principles themselves. A company can say it values fairness, transparency, accountability, privacy, and human oversight. Those words may even be sincerely meant. But unless there is a way to assign responsibility, test behavior, and enforce consequences, the principles remain closer to brand language than governance.

This is where AI creates an uncomfortable problem for software. Traditional professional responsibility doesn't fit the way software is built. A doctor can be held responsible for a diagnosis because the professional decision is usually attributable to the doctor. Software rarely works that way. A product decision, data choice, architecture tradeoff, model behavior, design constraint, release deadline, and legal interpretation all get mixed together before the system reaches a user.

So when an AI system harms someone, the natural question is not only "who wrote the code?" It is also:

- Who specified the behavior?
- Who selected the training data or evaluation data?
- Who approved the product risk?
- Who decided the human review was sufficient?
- Who monitored failures after release?
- Who had the power to stop deployment?

If responsibility cannot be traced through those questions, the system has been shipped rather than governed.

## Professionalism is not enough

One proposed answer is to treat [software engineers more like licensed professionals](/2026/07/21/review-software-malpractice-in-the-age-of-ai/). There is something attractive about that idea. Software systems now shape medicine, finance, transport, hiring, speech, policing, and public administration. It is strange that the people who build such systems often have less formal accountability than people in older professions whose mistakes affect fewer people.

But the analogy has limits.

Software is usually not produced by a lone professional exercising independent judgment. The engineer may understand the technical risk but lack authority over the business requirement. The product leader may own the user experience but not understand the model failure mode. The data team may know the bias in the dataset but not own the release decision. The legal team may approve a disclosure that is formally defensible but practically useless to users.

Licensing individual engineers would not solve that allocation problem on its own. It may raise the baseline of competence, and it may give engineers a stronger basis for refusing reckless work, but AI responsibility has to be assigned at the system level. Accountability has to include the organization, not just the coder.

## Soft law needs hard edges

That is why proposals for AI governance bodies are worth taking seriously. A [global or international coordinating body](/2026/07/31/review-agile-ethical-legal-model-ai-robotics-governance/) for AI and robotics would not solve enforcement on its own. It would, however, pull together the scattered pieces of soft law: professional guidelines, research norms, insurance requirements, audit expectations, publication standards, procurement rules, and sector-specific regulation.

This matters because AI systems cross borders more easily than laws do. The GDPR gives people enforceable rights within the European Union, but many AI harms do not stay in one place. A model may be trained in one country, deployed by a company in another, served through infrastructure in a third, and used on people who live everywhere.

Without institutions that can connect principles to incentives, the result is predictable. Companies follow the rules where enforcement is real and convert everything else into policy language.

The useful governance question is therefore not "what should AI value?" We already have many plausible lists. It is which institutions can make those values expensive to ignore.

## Crowds are intelligent, but not automatically wise

Collective intelligence adds another complication. [Crowds can outperform individuals](/2026/08/14/review-studying-wisdom-of-crowds-at-scale/). Aggregated judgment can be more accurate and more stable than the judgment of any one participant. This is true in markets, elections, forecasts, open-source communities, scientific review, and even in the simple way many small signals can produce a better result than one large opinion.

But crowds also herd. Social influence can make a group less accurate when people stop contributing independent judgment and start copying visible signals. Once that happens, the crowd is no longer a distributed intelligence system. It is an amplification system.

This distinction is important for AI governance because many modern systems are built out of feedback loops. Users rate content, models learn from users, recommender systems shape what users see, users respond to what was recommended, and the next version of the system absorbs the pattern. The "crowd" in such a system is not outside the technology. It is part of the technology.

So the question is not whether collective intelligence is good or bad. The question is whether the system preserves enough independent signal to make the crowd useful, and whether it has a way to detect when influence has collapsed into herding.

## Technology reveals rights

Technology also changes which rights become practically important.

The right to be forgotten, the right to public anonymity, and the right to disconnect are useful examples. These rights did not become meaningful because human interests suddenly changed. People always had interests in privacy, dignity, rest, and control over reputation. What changed was the power technology put in others' hands.

Search engines, social networks, cheap storage, facial recognition, workplace messaging, and always-on devices shifted power. One person, company, or state can now remember, locate, classify, and interrupt another person at a scale that older social norms were not built to handle. The underlying interest existed earlier, but the duty became visible only when technology made the imbalance sharp enough.

That is the strongest argument for treating some rights as ["revealed"](/2026/08/07/review-how-technological-advances-can-reveal-rights/) by technology. Not invented from nothing, but made urgent by a new imbalance of power.

## The actual work

AI governance will not be solved by choosing between ethics, law, or engineering. It needs all three.

Engineering gives us tests, audits, monitoring, incident response, system design, and evidence. Law gives us duties, remedies, procedures, and consequences. Ethics gives us the words for what is at stake before the law catches up.

The practical work is to connect them:

- Turn principles into concrete release criteria.
- Treat datasets, prompts, models, and evaluations as governed artifacts.
- Make responsibility traceable across product, engineering, data, legal, and leadership.
- Preserve independent human judgment where collective intelligence is being used.
- Recognize new technological rights before harm becomes normalized.
- Build institutions that make serious AI failures visible, attributable, and costly.

The real test of AI governance is not whether an organization can write a responsible AI policy. It is whether, when the system fails, the organization can answer a harder question clearly: who was responsible for knowing this could happen, and what power did they have to prevent it?

An organization that can answer that question has turned its ethics into governance.

## References

Danny Tobey, "Software Malpractice in the Age of AI: A Guide for the Wary Tech Company", AIES 2018.

Wendell Wallach and Gary E. Marchant, "An Agile Ethical/Legal Model for the International and National Governance of AI and Robotics", AIES 2018.

Camelia Simoiu, Chiraag Sumanth, Alok Mysore, and Sharad Goel, "Studying the Wisdom of Crowds at Scale", HCOMP 2019.

Jack Parker and David Danks, "How Technological Advances Can Reveal Rights", AIES 2019.
