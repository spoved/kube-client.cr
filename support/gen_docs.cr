#!/usr/bin/env crystal

require "file_utils"
require "../src/kube-client/version"

DOCS_DIR     = "docs"
VERSIONS_DIR = "src/kube-client"
LASTEST      = Kube::Client::VERSION
PROJ_NAME    = "kube-client.cr"

def for_each_version
  return unless Dir.exists?(VERSIONS_DIR)
  Dir.open(VERSIONS_DIR).each_child do |version|
    next unless version =~ /^v\d/
    yield version.chomp(".cr"), nil, "#{version.chomp(".cr")}.0"
  end
end

def git_commit
  `git rev-parse HEAD 2> /dev/null`.chomp
end

def get_git_tags
  `git show-ref --tags -d`.chomp.split("\n")
    .select(&.=~(/\^\{\}$/)).map do |line|
    parts = line.split(" ")
    {parts[1].gsub("refs/tags/", "").gsub("^{}", ""), parts[0]}
  end
end

def get_release_version
  tag = get_git_tags.find(&.[1].==(git_commit))
  if tag
    tag[0].lchop('v')
  else
    "master"
  end
end

def generate_docs_for(prefix, version)
  puts "Generating docs for: #{prefix} : #{version}"

  rel_ver = get_release_version
  docs_dir = File.join(".", DOCS_DIR, rel_ver, prefix)
  version_file = File.join(".", VERSIONS_DIR, "#{prefix}.cr")
  return unless File.exists?(version_file)
  FileUtils.rm_rf File.join(docs_dir) if Dir.exists?(docs_dir)
  FileUtils.mkdir_p(docs_dir) unless Dir.exists?(docs_dir)

  _generate_docs(version_file, docs_dir, rel_ver, git_commit, version)
end

def _generate_docs(version_file, docs_dir, rel_ver, git_commit, api_ver)
  args = [
    "doc",
    "--project-name", PROJ_NAME,
    "--output", docs_dir,
    "--project-version", rel_ver,
    "--source-refname", git_commit,
  ]

  # Dir.glob("./lib/k8s/src/k8s/*.cr").each do |file|
  #   args << file
  # end
  # args << File.join(".", "lib/k8s/src/versions", File.basename(version_file))
  args << version_file

  system "crystal", args

  File.open(File.join(docs_dir, "css", "style.css"), "a") do |f|
    f.puts "", gen_css(api_ver)
  end
end

def gen_css(version)
  <<-CSS
  html body div.sidebar div.sidebar-header div.project-summary span.project-version::after {
    content: "api: #{version}";
    display: block;
    clear: both;
  }
  CSS
end

def generate_release_docs
  `git fetch --all --tags`
  # Generate for master
  generate_release_docs_for("master", git_commit)
  docs = ["master"]

  current_ref = git_commit
  get_git_tags.each do |tag|
    versions = generate_release_docs_for(tag[0].lchop('v'), tag[1])
    docs << tag[0].lchop('v') unless versions.empty?
  end

  `git checkout master`
  generate_version_list(File.join(".", DOCS_DIR), docs, "K8S Releases")
end

def generate_release_docs_for(tag, commit)
  `git checkout #{commit}`
  `shards install`
  versions = [] of String
  for_each_version do |prefix, _, version|
    generate_docs_for(prefix, version)
    versions << prefix
  end
  docs_dir = File.join(".", DOCS_DIR, tag)
  generate_version_list(docs_dir, versions, "Kubernetes APIs") unless versions.empty?
  versions
end

def generate_version_list(docs_dir, docs, title = nil)
  return unless Dir.exists?(docs_dir)
  index = File.join(docs_dir, "index.html")
  File.open(index, "w") do |f|
    f.puts gen_index(title, docs.sort.reverse!)
  end
end

def gen_index(title, docs)
  String::Builder.build do |b|
    b.puts <<-HTML
        <!DOCTYPE html>
        <html lang="en">
        <div class="main-content">
        <h2>#{title}</h2>
        <ul>
        HTML
    docs.each do |doc|
      b.puts "<li><a href=\"#{doc}/index.html\">#{doc}</a></li>"
    end
    b.puts <<-HTML
    </ul>
    </div>
    HTML
  end
end

generate_release_docs
