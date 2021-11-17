#!/usr/bin/env crystal

VERSIONS_DIR = "src/kube-client"

# Generate versions files for each k8s version
Dir.open("lib/k8s/src/versions").children.each do |file|
  next if file =~ /\.cr$/
  File.open(File.join(VERSIONS_DIR, "#{file}.cr"), "w") do |f|
    f.puts %<require "./version">
    f.puts %<require "k8s/versions/#{file}">
    f.puts %<require "../kube/*">
  end
end
