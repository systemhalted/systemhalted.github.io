#!/usr/bin/env ruby
# frozen_string_literal: true

# One-time Jekyll-to-Org migration. The published site does not invoke Ruby or
# Pandoc; this script exists to document how the initial Org corpus was made.

require "cgi"
require "fileutils"
require "jekyll"
require "open3"
require "optparse"
require "pathname"
require "time"
require "uri"
require "yaml"

ROOT = Pathname.new(__dir__).join("..").expand_path

FORMER_NEWSLETTER_CATEGORIES = {
  "2024-06-25-embracing-timely-action" => ["Personal Essays"],
  "2024-06-28-balancing-diplomacy-firmness" => ["Personal Essays"],
  "2024-07-01-hidden-cost-of-ineffective-product-evaluation" => ["Software Engineering"],
  "2024-07-14-the-state-of-gurgaon" => ["Politics & Governance"],
  "2024-07-16-six-degrees-of-freedom" => ["Personal Essays"],
  "2024-07-19-leading-with-humility" => ["Personal Essays"],
  "2024-09-03-eliminating-inequality" => ["Society & Economy"],
  "2024-12-28-consumption-backlog-for-mindful-knowledge" => ["Personal Essays"],
  "2025-12-05-equality-idea-conditioning-inheritance" => ["Society & Economy"]
}.freeze

options = { pandoc: ENV.fetch("PANDOC", "pandoc") }
OptionParser.new do |parser|
  parser.on("--pandoc PATH") { |path| options[:pandoc] = path }
end.parse!

def front_matter(path)
  source = path.read
  match = source.match(/\A---\s*\n(.*?)^---\s*$\n?/m)
  return [{}, source] unless match

  data = YAML.safe_load(match[1], permitted_classes: [Date, Time], aliases: true) || {}
  [data, source[match.end(0)..] || ""]
end

def run_pandoc(binary, input, from:, to: "org")
  output, error, status = Open3.capture3(
    binary, "--from=#{from}", "--to=#{to}", "--wrap=none", stdin_data: input
  )
  raise "Pandoc failed: #{error}" unless status.success?

  output.strip
end

def decoded_route(route)
  URI::DEFAULT_PARSER.unescape(route).force_encoding(Encoding::UTF_8)
end

def list_value(value)
  Array(value).flatten.compact.map(&:to_s).map(&:strip).reject(&:empty?)
end

def org_bool(value)
  value == true || value.to_s.downcase == "true"
end

def org_date(value, filename)
  value ||= filename[/\A(\d{4}-\d{2}-\d{2})-/, 1]
  case value
  when Time then value.strftime("%Y-%m-%d %H:%M:%S %z")
  when Date then value.iso8601
  else value.to_s
  end
end

def repository_date(path)
  output, _error, status = Open3.capture3(
    "git", "log", "-1", "--format=%cs", "--", path.relative_path_from(ROOT).to_s,
    chdir: ROOT.to_s
  )
  status.success? && !output.strip.empty? ? output.strip : "1970-01-01"
end

def description_for(data, plain, title)
  description = data["description"].to_s.strip
  return description.gsub(/\s+/, " ") unless description.empty?

  candidate = plain.gsub(/\s+/, " ").strip
  candidate = "#{title} on SystemHalted." if candidate.empty?
  return candidate if candidate.length <= 240

  candidate[0, 237].sub(/\s+\S*\z/, "") + "..."
end

def preprocess_liquid(body, post_routes)
  converted = body.gsub(/\{%\s*highlight\s+([^\s%]+)\s*%\}(.*?)\{%\s*endhighlight\s*%\}/m) do
    language = Regexp.last_match(1).downcase
    language = "text" if language == "plaintext"
    "```#{language}\n#{Regexp.last_match(2).strip}\n```"
  end
  converted.gsub!(/\{%\s*post_url\s+([^\s%]+)\s*%\}/) do
    key = Regexp.last_match(1)
    post_routes.fetch(key) { raise "Unknown post_url target: #{key}" }
  end
  converted.gsub!(/\{%\s*include\s+svg\/([^\s%]+)\s*%\}/) do
    include_path = ROOT.join("_includes", "svg", Regexp.last_match(1))
    raise "Missing SVG include: #{include_path}" unless include_path.file?

    include_path.read
  end
  converted.gsub!(/\{\{\s*["']([^"']+)["']\s*\|\s*relative_url\s*\}\}/, "\\1")
  converted.gsub!(/\{\{\s*site\.baseurl\s*\}\}/, "")
  converted.gsub!(/\{\{\s*site\.url\s*\}\}/, "https://systemhalted.in")
  liquid = converted.scan(/\{%.*?%\}|\{\{.*?\}\}/m)
  raise "Untranslated Liquid: #{liquid.uniq.join(', ')}" unless liquid.empty?

  converted
end

def keyword_lines(data, title:, description:, date:, route:, draft: false)
  categories = list_value(data["categories"] || data["category"])
  tags = list_value(data["tags"] || data["tag"])
  lines = ["#+TITLE: #{title}", "#+DESCRIPTION: #{description}"]
  lines << "#+DATE: #{date}" unless date.to_s.empty?
  lines << "#+CATEGORIES: #{categories.join(', ')}" unless categories.empty?
  lines << "#+TAGS: #{tags.join(', ')}" unless tags.empty?
  lines << "#+PERMALINK: #{route}" unless route.to_s.empty?
  lines << "#+COMMENTS: true" if org_bool(data["comments"])
  lines << "#+TOC: true" if org_bool(data["toc"])
  lines << "#+LAST_MODIFIED: #{data['last_modified_at']}" if data["last_modified_at"]
  featured_image = data["featured_image"]
  if featured_image&.start_with?("/") && !ROOT.join(featured_image.delete_prefix("/")).file?
    warn "Skipping missing legacy featured image: #{featured_image}"
    featured_image = nil
  end
  lines << "#+FEATURED_IMAGE: #{featured_image}" if featured_image
  lines << "#+FEATURED_IMAGE_ALT: #{data['featured_image_alt']}" if data["featured_image_alt"]
  lines << "#+FEATURED_IMAGE_CAPTION: #{data['featured_image_caption']}" if data["featured_image_caption"]
  lines << "#+DRAFT: true" if draft || data["published"] == false
  lines
end

def write_org(path, keywords, body)
  FileUtils.mkdir_p(path.dirname)
  path.write("#{keywords.join("\n")}\n\n#{body.rstrip}\n")
end

config = Jekyll.configuration(
  "source" => ROOT.to_s,
  "destination" => ROOT.join("_site-migration-map").to_s,
  "show_drafts" => true,
  "future" => true,
  "unpublished" => true,
  "quiet" => true
)
site = Jekyll::Site.new(config)
site.reset
site.read

routes = {}
site.collections.each_value do |collection|
  collection.docs.each { |document| routes[Pathname.new(document.path).expand_path.to_s] = decoded_route(document.url) }
end

post_routes = {}
routes.each do |path, route|
  base = File.basename(path).sub(/\.(?:md|html)\z/, "")
  post_routes[base] = route if path.include?("/_posts/")
end

sources = {
  ROOT.join("collections/_posts") => ROOT.join("org/posts"),
  ROOT.join("collections/_drafts") => ROOT.join("org/drafts"),
  ROOT.join("collections/_emacs") => ROOT.join("org/emacs")
}

sources.each do |source_dir, destination_dir|
  source_dir.children.sort.each do |source|
    next unless source.file?

    data, body = front_matter(source)
    source_key = source.basename.to_s.sub(/\.(?:md|html)\z/, "")
    if FORMER_NEWSLETTER_CATEGORIES.key?(source_key)
      data["categories"] = FORMER_NEWSLETTER_CATEGORIES.fetch(source_key)
      data["category"] = nil
      data["tags"] = list_value(data["tags"]).reject { |tag| tag.casecmp?("newsletter") }
    end
    existing = data["org_source"] && ROOT.join(data["org_source"])
    route = routes[source.expand_path.to_s]
    route ||= data["permalink"]
    if source_dir.basename.to_s == "_drafts" &&
       data["date"].nil? && source.basename.to_s !~ /\A\d{4}-\d{2}-\d{2}-/
      date = repository_date(source)
      slug = source.basename.to_s.sub(/\.(?:md|html)\z/, "").tr(" ", "-")
      route = "/#{date.tr('-', '/')}/#{decoded_route(slug)}/"
    elsif route.nil? && source_dir.basename.to_s == "_drafts"
      base = source.basename.to_s.sub(/\.(?:md|html)\z/, "")
      date = org_date(data["date"], base)
      slug = base.sub(/\A\d{4}-\d{2}-\d{2}-/, "").tr(" ", "-")
      route = "/#{date[0, 10].tr('-', '/')}/#{decoded_route(slug)}/"
    end

    if existing&.file?
      original = existing.read
      original.sub!(/^#\+JEKYLL_COMMENTS:/i, "#+COMMENTS:")
      original.sub!(/^#\+JEKYLL_TOC:/i, "#+TOC:")
      original.sub!(/\A((?:#\+.*\n)+)/) do |header|
        header.match?(/^#\+PERMALINK:/i) ? header : "#{header}#+PERMALINK: #{route}\n"
      end
      existing.write(original)
      next
    end

    input_format = source.extname == ".html" ? "html+raw_html" : "markdown-yaml_metadata_block+raw_html+footnotes"
    prepared = preprocess_liquid(body, post_routes)
    org_body = run_pandoc(options[:pandoc], prepared, from: input_format)
    plain = run_pandoc(options[:pandoc], prepared, from: input_format, to: "plain")
    title = data.fetch("title").to_s
    description = description_for(data, plain, title)
    filename = source.basename.to_s.sub(/\.(?:md|html)\z/, ".org")
    draft = source_dir.basename.to_s == "_drafts"
    date = org_date(data["date"], filename)
    date = repository_date(source) if draft && date.empty?
    keywords = keyword_lines(
      data, title: title, description: description, date: date, route: route, draft: draft
    )
    write_org(destination_dir.join(filename), keywords, org_body)
  rescue StandardError => error
    warn "#{source.relative_path_from(ROOT)}: #{error.message}"
    raise
  end
end

def convert_page(source_name, output_name, route, pandoc, post_routes, remove_newsletter: false)
  source = ROOT.join(source_name)
  data, body = front_matter(source)
  if remove_newsletter
    body = body.gsub(/\nI also publish <a href=.*?\n\n/m, "\n")
    body = body.gsub(/Everything I do — this blog, the Kartavya Path newsletter,/, "Everything I do — this blog,")
  end
  prepared = preprocess_liquid(body, post_routes)
  org_body = run_pandoc(pandoc, prepared, from: "markdown-yaml_metadata_block+raw_html+footnotes")
  title = data.fetch("title").to_s
  description = description_for(data, run_pandoc(pandoc, prepared, from: "markdown-yaml_metadata_block+raw_html", to: "plain"), title)
  write_org(
    ROOT.join("org/pages", output_name),
    keyword_lines(data, title: title, description: description, date: nil, route: route),
    org_body
  )
end

convert_page("about.md", "about.org", "/about/", options[:pandoc], post_routes, remove_newsletter: true)
convert_page("404.md", "404.org", "/404.html", options[:pandoc], post_routes)

data = {
  projects: YAML.safe_load(ROOT.join("_data/projects.yml").read, aliases: true),
  themes: YAML.safe_load(ROOT.join("_data/themes.yml").read, aliases: true),
  games: YAML.safe_load(ROOT.join("_data/jsgames.yml").read, aliases: true),
  history: YAML.safe_load(ROOT.join("_data/os_history.yml").read, aliases: true),
  taxonomy: YAML.safe_load(ROOT.join("_data/taxonomy.yml").read, aliases: true)
}

project_org = data[:projects].flat_map do |section, projects|
  heading = section == "available" ? "* Available now" : "* In development"
  [heading] + projects.flat_map do |project|
    links = [project["primary_cta"], project["secondary_cta"]].compact.map do |cta|
      "[[#{cta['url']}][#{cta['label']}]]"
    end
    ["** #{project['name']} — #{project['status']}", project["description"],
     "Tags: #{list_value(project['tags']).map { |tag| "=#{tag}=" }.join(', ')}",
     links.join(" · "), ""]
  end
end.join("\n")
write_org(ROOT.join("org/data/projects.org"), ["#+TITLE: Project data"], project_org)

theme_org = data[:themes].flat_map do |theme|
  description = theme["description"].to_s.sub("Powers this very site.", "It previously powered this site.")
  ["* #{theme['name']} v#{theme['version']}", description,
   "[[#{theme['demo']}][Live demo]] · [[#{theme['repo']}][GitHub]] · [[#{theme['rubygems']}][RubyGems]]",
   "Install: =gem install #{theme['gem']}=", ""]
end.join("\n")
write_org(ROOT.join("org/data/themes.org"), ["#+TITLE: Theme data"], theme_org)

game_org = data[:games].flat_map do |game|
  ["* [[#{game['url']}][#{game['title']}]]", game["description"], ""]
end.join("\n")
write_org(ROOT.join("org/data/jsgames.org"), ["#+TITLE: JavaScript game data"], game_org)

history_org = ["* Fortunes"] + data[:history].fetch("fortunes").map { |line| "- #{line}" }
history_org += ["", "* Timeline", "| Year | Event |", "|-"]
history_org += data[:history].fetch("timeline").map { |item| "| #{item['year']} | #{item['event']} |" }
write_org(ROOT.join("org/data/os-history.org"), ["#+TITLE: Operating system history data"], history_org.join("\n"))

taxonomy_org = data[:taxonomy].fetch("themes").reject { |theme| theme["id"] == "newsletter" }.flat_map do |theme|
  ["* #{theme['title']}", theme["description"]] + theme.fetch("categories").flat_map do |category|
    ["** #{category['name']}", category["description"], ""]
  end
end.join("\n")
write_org(ROOT.join("org/data/taxonomy.org"), ["#+TITLE: Site taxonomy"], taxonomy_org)

pages = {
  "projects.org" => ["Projects", "Projects by Palak Mathur, including released work, public betas, and selected work in progress.", "/projects/", "../data/projects.org"],
  "themes.org" => ["Themes", "Open-source themes built and published by Palak Mathur.", "/themes/", "../data/themes.org"],
  "jsgames.org" => ["JavaScript Games", "Small browser games and experiments.", "/jsgames/", "../data/jsgames.org"]
}
pages.each do |filename, (title, description, route, include_path)|
  write_org(
    ROOT.join("org/pages", filename),
    keyword_lines({}, title: title, description: description, date: nil, route: route),
    "#+INCLUDE: \"#{include_path}\""
  )
end

webcmd_data, webcmd_body = front_matter(ROOT.join("webcmd/index.html"))
webcmd_org = run_pandoc(options[:pandoc], webcmd_body, from: "html+raw_html")
write_org(
  ROOT.join("org/pages/webcmd.org"),
  keyword_lines(
    webcmd_data,
    title: webcmd_data.fetch("title"),
    description: "A terminal-style interface to the SystemHalted archive.",
    date: nil,
    route: "/webcmd/"
  ),
  webcmd_org
)

puts "Migrated #{sources.sum { |source, _| source.children.count(&:file?) }} collection files and authored pages to Org."
