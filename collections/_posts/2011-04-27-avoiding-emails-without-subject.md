---
layout: post
title: Avoiding emails without Subject?
date: 2011-04-27 22:14:30.000000000 -05:00
type: post
parent_id: '0'
published: true
password: ''
status: publish
category:
- Technology
meta:
  _edit_last: '547454'
  geo_latitude: '27.129264'
  geo_longitude: '78.054729'
  geo_accuracy: '0'
  geo_address: street, Agra H O, Uttar Pradesh, India
  geo_public: '0'
  _wpas_done_yup: '1'
  _wpas_done_twitter: '1'
  _wpas_skip_fb: '1'
  reddit: a:2:{s:5:"count";s:1:"0";s:4:"time";s:10:"1329622596";}
author:
  login: palakmathur
  email: palakmathur@gmail.com
  display_name: Palak Mathur
  first_name: Palak
  last_name: Mathur
permalink: "/2011/04/27/avoiding-emails-without-subject/"
tags:
- technology
- leadership
---
More often than not I used to compile a fantastic mail to send to my colleagues (even managers) in office and just after clicking **Send**, it used to strike me that I had missed mentioning the subject. So, I requested a few friends on [Infosys](http://www.infosys.com/) internal blogs to send me the script for Outlook. Nikhil Kurien mailed me the requested piece of code back in 2007. I was just cleaning up my mails and thought it would be better if I keep it on my blog, as it would make it easy for me to access it whenever I wish rather than searching for the mail.

So, here are the steps to set this up:

1. Open your Outlook.
2. Press `Alt+F11` (this opens the [Visual Basic](http://msdn.microsoft.com/en-us/vbasic/default.aspx) editor).
3. On the left pane you will see **Microsoft Outlook Objects**, expand this. Now you can see **ThisOutLookSession**.
4. Click on **ThisOutLookSession**.
5. Copy and paste the following code in the right pane:

{% highlight vb %}
   Private Sub Application_ItemSend(ByVal Item As Object, Cancel As Boolean)
     Dim strSubject As String
     strSubject = Item.Subject
       If Len(strSubject) = 0 Then
         Prompt$ = "Subject is Empty. Are you sure you want to send the Mail?"
         If MsgBox(Prompt$, vbYesNo + vbQuestion + vbMsgBoxSetForeground, "Check for Subject") = vbNo Then
          Cancel = True
         End If
       End If
   End Sub
{% endhighlight %} 

6. Save this and now close the VB Code editor and take a breath. From now on, this macro will make sure you do not make the mistake of sending an email without subject.
