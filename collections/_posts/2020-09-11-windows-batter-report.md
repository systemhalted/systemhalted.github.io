---
layout: post
title: Windows 10 Battery Report
category:
- Technology
comments: true
description: Battery troubles? Generate a battery report on Windows 10.
tags:
- technology
---
In my last post, I told you that I recently bought a used ThinkPad T430 from ebay. The first thing I noticed was that the battery drains within no time and I need to keep the laptop plugged in, which in turn means there is only little mobility that it affords me. So, I wanted to check how much battery life is remaining. Windows 10 comes with a great power tool to generate battery report. To generate this report, do the following:

1. Open a Powershell with elevated (admin) access.
2. Run the following command:

{% highlight powershell %}
powercfg /batteryreport
{% endhighlight %}

3. This will generate the report[^fn1] in the current folder with a file named `battery-report.html`. Open this file in a browser. 


*Notes:*


[^fn1]: At the bottom of the report you will see the section `Current estimate of battery life based on all observed drains since OS install`. This will have two columns, `At Full Charge` and `At Design Capacity`. These will be the time the battery will retain juice at full charge compared to what it was designed for respectively. Read [this](https://www.pcmag.com/how-to/how-to-check-your-laptop-battery-health-in-windows-10) article on PCMag for more details
