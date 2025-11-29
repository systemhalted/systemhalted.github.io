The S-expression `(* A B)` is just a linear way to write that tree: put the operator at the front, then the operands, and wrap the whole thing in parentheses.

So you can think of Clojure’s "prefix notation" as:

- A tree of operations and values
- Written in one line as a parenthesized list: operator first, then its children

Once that clicks, nested expressions start to feel very natural, because the code mirrors the tree structure directly.

### "But I already use prefix, don’t I?"

Prefix notation sounds exotic, but you already use something very close to it in other languages.

In Python, a simple print looks like this:

{% highlight python %}
print("Hello World!")
{% endhighlight %}

The function name comes first, followed by the argument in parentheses.

In Clojure, the equivalent is:

{% highlight clojure %}
(print "Hello World!")
{% endhighlight %}

Same idea: the "operation" is at the front, followed by its arguments. The main differences are:

- Clojure uses a single pair of parentheses around the entire call
- Arguments are separated by spaces instead of commas

So while math operators like `+`, `-`, `*`, and `/` look unusual in prefix form, most other function calls feel very familiar once you notice this pattern.

### Readability and taste

I have never built a full-scale production system in Clojure or Lisp, but I still find Clojure code easier to read than a lot of Java code.

It is easy to make Java code look horrible. It is surprisingly hard to make Clojure code look horrible in the same way, because:

- The syntax is extremely regular
- The structure of the code mirrors the structure of the data and the operations

That doesn’t mean nobody can write unreadable Clojure, but you have to work a bit harder to fight the language.

### Further reading and watching

If you’re curious about the learning curve and the "Lisp way" of thinking, I highly recommend:

- [The Nature of Lisp](http://www.defmacro.org/ramblings/lisp.html)
- [2 Myths and 2 Facts About Clojure That Change Everything](http://blog.cognitect.com/blog/2015/9/21/2-myths-and-2-facts-about-clojure-that-change-everything)

Some talks and articles that were shared in the original Java Ranch thread:

- [(Neal's) Master Plan for Clojure Enterprise Mindshare Domination – Neal Ford](https://www.youtube.com/watch?v=2WLgzCkhN2g&feature=youtu.be&t=1619)
- [Simple Made Easy – Rich Hickey](http://www.infoq.com/presentations/Simple-Made-Easy)
- [Sneaking Clojure Past the Boss](http://www.coderanch.com/t/586641/clojure/Sneaking-Clojure-Boss)
- [Selling Clojure to Business](https://blog.juxt.pro/posts/selling-clojure.html)
- [PolyConf 15: Contracts as Types – Jessica Kerr](https://www.youtube.com/watch?v=zLyd_Ey1GPM)

If prefix notation and all those parentheses still feel odd, that’s fine. Our brains are heavily trained on infix. Spend a bit of time thinking in trees instead of lines of code, and Clojure’s syntax starts to feel less like an alien language and more like a very direct way of writing down structure.


Edit: (28th Nov 2025) Updated with latest understanding of some terminology.