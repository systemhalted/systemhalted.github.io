---
layout: post
title: Migrating SVN Repo to Git
date: 2016-06-24
type: post
published: true
comments: true
status: publish
categories:
- Technology
tags:
- git
- svn
- migration
description: How to migrate SVN repository to Git?
---

Recently, I had to move one of my SVN repository from SVN to Git. As there was no tag or trunk and only branch (it is weird but true) it was fairly simple. Git comes with a great Git-Svn toolkit that you can use. However, there are few caveats and I will tell you how I overcame them. 

I started by creating a new folder on my machine. On Git bash, I simply typed the following command:

{% highlight sh %}
git svn clone https://subversion.abc.com/svn/api-services/branches/apiservices_sprint.dev/test-api
{% endhighlight %}

It took some time and my repo was cloned. However, when I did git log to check history, the comments were of following format:

![Not so good log]({{ site.url }}/assets/images/git-log.png "git log")


It doesn't look like what normal and proper git logs look like. There are few problems. Firstly, the author is unidentifiable:

  ```
    Author: xyz <xyz@4c9131da-42a3-4784-a41a-982bb726ad01>
  ```

Second, there is way too much meta data. What I will do with the element git-svn-id? I don't need it.

The meta-data issue can be resolved with modifying the command by adding --no-metadata to it.

{% highlight sh %}
    git svn clone https://subversion.abc.com/svn/api-services/branches/apiservices_sprint.dev/test-api test-api --no-metadata
{% endhighlight %}

Still few things remain undesirable. The author of the commits are still not properly identifiable. I wanted a way to extract the author information from the SVN log and replace it with the proper author information. To do that, I had to extract the logs in an xml format, grep-ed on author and stripped the xml tags. Git-scm came to the rescue with the simple command for this:

{% highlight sh %}
    svn log --xml | grep author | sort -u | perl -pe 's/.*>(.*?)<.*/$1 = /'  > users.txt
{% endhighlight %}

I got the list of users in a text file. In which I provided further information in key=value pair. For eg:

```
    xyz=ABC DEF <abc.def@gmail.com>
```

Now, again I deleted the previously cloned repo and ran the following command

{% highlight sh %}
    git svn clone https://subversion.abc.com/svn/api-services/branches/apiservices_sprint.dev/test-api --authors-file=users.txt --no-metadata test-api
{% endhighlight %}

And, finally, I got the nice clone with good looking comments:

  ![Better log]({{ site.url }}/assets/images/git-log1.png "git log")

This looks cleaner and much better than the previous commit message and more **Gitly**, if I may use that word. 