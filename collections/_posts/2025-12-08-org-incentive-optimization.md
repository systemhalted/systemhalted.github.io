---
layout: post
title: Org Incentive Optimization Problem
category:
- Personal Essays
tags:
- personal
- opinion
- movie-review
- leadership
comments: true
featured: true
description: Most orgs are unknowingly running an “Org Incentive Optimization” algorithm that over-rewards flashy new platforms and under-values quiet reliability work, so you have to translate maintenance into visible, computable outcomes.
---
Recently, in a conversation on [LinkedIn](https://www.linkedin.com/posts/jessewarden_heard-a-rumor-google-used-to-have-an-incentive-activity-7403871145076162560-IfQs?utm_source=share&utm_medium=member_desktop&rcm=ACoAAAEFJMcB_miK-56ZKPbmvTNGUxM6IrkeN_M), I came to realization that most companies are secretly running an algorithm they’ve never actually written down.

I call it the **Org Incentive Optimization Problem**.

Here’s how it usually behaves:

You say:  
> “I fixed a bunch of bugs, cleaned up tech debt, and made the platform more reliable.”

The system hears:  
> “did routine work”.

You say:  
> “I built a new platform.”

The system hears:  
> “high impact, visionary, promotable”.

Same keyboard. Same brain. Completely different reward curve.

The catch is that reliability and maintenance work are **compounding assets**.  
They just don’t come with launch emails, codenames, or shiny demos.

Avoided outages never show up on a slide.  
Stable systems don’t page executives at 2am.  
So they quietly vanish from the story.

From a computing perspective, this is a messy **credit-assignment** problem with delayed rewards and noisy signals.

From a human perspective, it looks like this:

- People chase visible “new” work, even when the real value is in strengthening what already exists.  
- Platform teams feel pressure to rebrand every major refactor as a “new platform” just to get air cover.  
- The folks who keep things boring and dependable get labeled “steady” instead of “high potential”.

If you model it in CS terms, it roughly looks like this:

**Input**

- A graph of teams, platforms, incidents, and features  
- Noisy signals: outages, launches, OKRs, customer metrics  
- Human agents who optimize whatever you measure  

**Objective**

Maximize:

- Reliability  
- Long-term velocity  
- Fair rewards for “unsexy” maintenance work  

Minimize:

- Cargo-cult “new platforms”  
- Incentive gaming  
- Burnout and PIPs for the people keeping it alive  

Most orgs end up running a greedy online heuristic:

```txt
if (work.isVisibleLaunch()) {
    promote++;
} else if (work.isQuietReliability()) {
    shrug++;
}
```

Bug fixing gets treated as constant-time hygiene,
while “new platform” is treated as *quadratic impact*,
even when the real business value is reversed.

The trick, if you are inside the system:

Make reliability work computable.
Never leave it as “I fixed bugs”.

Translate it into:

>I reduced incident rate by 40%.

>I removed a whole class of failures that used to wake people up every weekend.

>I made it safer and faster for five other teams to ship.

Same work.  
Different representation in the algorithm.  
Very different outcome.  
