---
---
// Builds an elasticlunr index for on-page commands (webcmd).

var siteIndex = elasticlunr(function () {
  this.addField('title');
  this.addField('layout');
  this.addField('content');
  this.setRef('id');
});

{% assign count = 0 %}{% for post in site.posts %}
siteIndex.addDoc({
  title: {{ post.title | jsonify }},
  layout: {{ post.layout | jsonify }},
  content: {{ post.content | jsonify | strip_html }},
  id: {{ count }}
});
{% assign count = count | plus: 1 %}{% endfor %}

var siteStore = [{% for post in site.posts %}{
  title: {{ post.title | jsonify }},
  link: {{ post.url | absolute_url | jsonify }},
  layout: {{ post.layout | jsonify }},
  snippet: {{ post.content | jsonify | strip_html | truncate: 140 }}
}{% unless forloop.last %},{% endunless %}{% endfor %}];

function siteSearch(query) {
  if (!query || !siteIndex) {
    return [];
  }
  return siteIndex.search(query, { expand: true });
}
