---
layout: post
title: You'll need a new app to open this windowsdefender
category: System Administration
tags: [Powershell, Unix-shell, Windows]
comments: true
---

Recently I purchased a used ThinkPad T430[^fn1] from ebay. However, when I tried to open the Windows Defender, I saw the following pop-up:

![Never say die popup]({{ site.url }}/assets/images/WindowsDefenderPopUp.png "Windows Defender Pop-up")

Apparently, this happens if you unistall a third-party Anti-virus software. But it is easy to fix it by following steps

1. Open Powershell with elevated (Admin) access

2. Run following command

``` sh
Add-AppxPackage -Register -DisableDevelopmentMode “C:\Windows\SystemApps\Microsoft.Windows.SecHealthUI_cw5n1h2txyewy\AppXManifest.xml”
```

That's it. Done!

[^fn1]: [Lenovo ThinkPad T430](https://www.lenovo.com/us/en/laptops/thinkpad/t-series/t430/)
