---
layout: post
date: 2012-12-15 21:45
title: As Touch is to UNIX, New-Item is to Windows PowerShell
category: System Administration
tags: [Powershell, Unix-shell, Windows]
comments: true
description: As Touch is to UNIX, New-Item is to Windows PowerShell
---

Unix has a command called Touch that creates an empty file

	$ touch touch_test.txt  
	touch_test.txt 

This command is not available in Windows PowerShell. However, there is a command in Powershell which also does the same - `New-Item`

	PS C:\Documents and Settings\Administrator\Workspace>New-item new_file.txt 
<br>

This will ask you to enter a `Type`

	Type: file 

The output will look something like this:


    Directory: C:\Documents and Settings\Administrator\Workspace


	Mode                LastWriteTime            Length   Name
	----                -------------            ------   ----
	-a---             12/15/2012   9:32 PM          0     new_file.txt

Try to use `Directory` as Type. Check it yourself what it does.

You can also specify the type inline with the command

	PS C:\Documents and Settings\Administrator\Workspace>New-item palakmathur.txt -type file 

The output will look something like this:


     Directory: C:\Documents and Settings\Administrator\Workspace

	 Mode                LastWriteTime            Length   Name 
	 ----                -------------            ------   ---- 
	 -a---             12/15/2012   9:32 PM          0     palakmathur.txt

Try this command and I will be soon back with another command. Till then enjoy PowerShell.