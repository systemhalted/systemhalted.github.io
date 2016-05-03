---
layout: post
title: Traceability Matrix - How important is its role in an Agile World
date: 2016-04-02
type: post
published: true
comments: true
status: publish
categories:
- Technology
- Agile
tags:
- traceability
- traceability matrix
---
Requirements traceability is “the ability to describe and follow the life of a requirement, in both a forwards and backwards direction (i.e., from its origins, through its development and specification, to its subsequent deployment and use, and through all periods of on-going refinement and iteration in any of these phases)” [1]. It is primarily useful for verification and validation to make sure that the right processes have been used to build the right system. Mostly in the old world, namely, Waterfall, the way to maintain traceability was using Requirements Traceability Matrix or simply Traceability Matrix (RTM). However, from my experience, I can certainly vouch that I have never looked at RTM except for during software audits.

The value that you get by maintaining RTM is not very cost effective. RTM is one more document in a chain of document that requires maintainence. Everytime a requirement changes, you not only need to modify code and your acceptance tests, which is basically what you should do, but also modify the RTM. Over the time cost to maintain RTM becomes so high that the value attained by keeping the document alive is lost.

In 2008, there was a thread on Yahoo! Groups on Traceability in Agile. I would like to quote a [reply by](https://groups.yahoo.com/neo/groups/agile-testing/conversations/topics/13320?threaded=1&p=7) [Michael Bolton](http://www.developsense.com) here:


      I think of it as something more abstract--a concept that
      helps us understand the historical links between one set of ideas and
      another, or an answer to a question in the general form of "Why did we do
      that?" More extremely, it might be "Who did X, and what did they do, and
      why, or when, or how did they do it?" Answers to those questions can take
      many forms, depending on the culture. Conversations, stories, strategic
      themes, histories, logs, journals, source code, automated tests, design
      documents, daily scrums, email, and (yes) spreadsheets are all media in
      which traceability might be found, and all of them can be passed from one
      person to another. But only some of these forms are documents that are
      explicitly designed for that purpose and for no other. I'd suggest that you
      need traceability if there's a danger of losing corporate memory that is
      genuinely valuable--but what's the risk of that when it's already available
      in so many forms?

      Now, there are plausibly legitimate answers to a question like this. The
      trouble (and clutter, and extra expense, and extra overhead) tends to come
      when we haven't asked the question at all. That would be the suggestion
      that I would make to the Original Poster: Someone wants traceability? Ask
      what they want it for, how often they'll want it, the form in which they'll
      want it, the forms in which they might be able to accept it--and then ask if
      the cost will be matched by value. Things that can be read by a human
      typically require a human to write them--yet most projects I've seen tend to
      be short on extra humans.


These days there is a ask to automatically create RTMs. Questions that we need to ask as suggested in the above reply by Michael Bolton are: 1) What will
happen if I do? 2) What won't happen if I do? 3) What will happen if I don't? 4) What won't happen if I don't?

Though automating RTMs is a great idea but again do we really need them? In the article "[The Trouble with Tracing: Traceability Dissected](https://www.cmcrossroads.com/article/trouble-tracing-traceability-dissected)", they talk about Nine Gripes against Traceability, which I am reproducing here:

* It causes more artifacts, more overhead and more work to create and maintain traceability matrices that are going to get hopelessly out of date because changes are inevitable
* It encourages “analysis paralysis” and heavy “up front” planning and design
* It imposes unnecessary restrictions upon the speed and productivity of development
* It is a fool’s errand that amounts to smoke and mirrors to provide an illusion about control and certainty regarding mostly redundant pieces of information already in the code and the tests
* It goes against the values in the “Agile Manifesto” because traceability emphasizes comprehensive documentation over working software and contract negotiation over customer collaboration
* It makes it harder to make necessary changes and encourages rigidity rather than flexibility
* It assumes a waterfall-based lifecycle with end-of-phase hand-offs to different functional groups
* It increases the amount of “software waste” for time spent seeking information and increases the duration and amount of “inventory” (partially completed, “in progress” functionality)
* It doesn’t readily fit iterative development working in short-cycles with close customer collaboration

In another article by same authors called "[Lean-Agile Traceability: Strategies and Solutions](https://www.cmcrossroads.com/article/lean-agile-traceability-strategies-and-solutions?page=0%2C2)", they also provide solutions:

1. Recognize that Traceability is not Tracing
2. Use Version-Control and Change-Tracking Tools
3. Basic Integration between Version-Control and Change-Tracking
4. [Task-Based Development (TBD)](https://www.cmcrossroads.com/article/principles-agile-version-control-ood-tbd)
5. Test-Driven Development (TDD)
6. Simple Tools: Wikis, and Wiki-based Specification Frameworks
7. Event-Based Traceability (EBT)
8. TDD/BDD + TBD + IDE = EBT 4 Free?
9. Search-based Traceability

I think the maturity that ATDD (BDD), TDD, TBD nad EBT bring are far more worthy than creating a separate RTM. With TDD/BDD, a single engineering task takes a single requirement through the entire lifecycle: specification (writing the test for the behavior), implementation (coding the behavior), verification (passing the test for the behavior), and design as explained in the article above. The article further adds, "The change-set that I commit to the repository at the end of my change-task represents all of that work across the entire lifecycle of the realization of just that one requirement. The ID of that one task or requirement can then be associated with the change-set as a result of the commit operation/event taking place."

Most of the advantages that Traceability provides can be obtained through TDD, Continuous Integration and Proper Version Control system like Git. A high-level stories can be maintained in a system like Version One or Project wiki in Enterprise Github wiki page and the same story id can be used while committing changes in the version control for the tests and the application code. If needed, the results of these can be monitored through a tool like Splunk for reporting purposes.

If you are still thinking about Traceability Matrix, it is high time you read the above articles before making up your mind. Because there are n-number of ways to do so, RTM might not be one of them.




