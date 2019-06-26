require "./lib/spoved/src/ext/string"

SCHEMA_DIR = File.expand_path "./lib/kubernetes-json-schema"
MODELS_DIR = File.expand_path "./src/kube/models"
SKIP_FILES = ["_definitions.json", "all.json", "intorstring-util-intstr.json", "intorstring.json",
              "quantity-resource.json", "quantity.json"]

INCLUDE_FILES = ["podlist.json"]

KUBE_VERSIONS = [
  "v1.12.0",
  # "v1.14.0",
]

KLASS_ALIASES = Hash(String, String).new

def parse_schema
  Dir.open(SCHEMA_DIR).children.sort.each do |ver|
    next unless File.directory?(File.join(SCHEMA_DIR, ver))
    next unless ver =~ /^v(\d+\.\d+\.\d+)$/

    # Minikube ver
    next unless KUBE_VERSIONS.includes?(ver)

    api_klass = "V#{$1}".gsub('.', '_')

    out_dir = File.join(MODELS_DIR, ver)
    # `rm -rf #{out_dir}` if Dir.exists?(out_dir)

    Dir.mkdir(out_dir) unless Dir.exists?(out_dir)

    Dir.cd(out_dir) do
      files = Array(String).new

      Dir.open(File.join(SCHEMA_DIR, ver)).children.sort.each do |file|
        next unless file =~ /json$/
        # next if file =~ /customresource|v1/
        next unless INCLUDE_FILES.includes?(file)
        # next if SKIP_FILES.includes?(file)

        input = File.join(SCHEMA_DIR, ver, file)
        output = file.chomp(".json") + ".cr"

        files << input

        next if File.exists?(output)

        # puts input
        # if !system("quicktype -s schema --lang cr -o #{output} #{input}")
        #   puts "ERROR: Failed to parse file: #{input}"
        # end
      end

      failed = false
      unless File.exists?("all.temp")
        puts "Running quicktype command"

        last_dropped = ""
        while !system("quicktype -s schema --lang cr -o all.temp #{files.join(' ')}")
          failed = true
          last_dropped = files.pop
        end

        if failed
          puts "Last file to be dropped: #{last_dropped}"
          exit 1
        end
      end
    end

    # break
  end
end

def find_klasses(contents : Array(String))
  puts "Finding Classes"
  klass_info = Hash(String, NamedTuple(start: Int32, end: Int32, name: String, contents: Array(String))).new
  alias_info = Hash(String, NamedTuple(start: Int32, end: Int32, name: String, contents: Array(String))).new

  # Start looking for classes
  current_name = ""
  contents.each_index do |i|
    if contents[i] =~ /^class\s+(\w+)$/
      current_name = $1

      comment_index = find_comments(i, contents)

      contents.each_index(start: i, count: contents.size) do |e|
        if contents[e] =~ /^end$/
          klass_info[current_name] = {
            start:    comment_index,
            end:      e,
            name:     current_name,
            contents: contents[comment_index..e],
          }
          break
        end
      end
    end

    if contents[i] =~ /^alias\s+(\w+)\s+=/
      current_name = $1
      puts "Found alias: #{$1}"
      comment_index = find_comments(i, contents)

      info = {
        start:    comment_index,
        end:      i,
        name:     current_name,
        contents: contents[comment_index..i],
      }

      unless info[:contents].grep(/#{current_name}Class/).empty?
        alias_info[current_name] = info
      end
    end
  end

  klass_info.keys.each { |k| KLASS_ALIASES[k] = k.klassify.gsub("::Class", "") }
  alias_info.keys.each { |k| KLASS_ALIASES[k] = k.klassify }
  {
    klass_info: klass_info,
    alias_info: alias_info,
  }
end

def find_comments(index, contents)
  # Search for comments
  comment_index = index - 1
  loop do
    break if contents[comment_index] !~ /^#/
    comment_index = comment_index - 1
  end
  comment_index = comment_index + 1
  comment_index
end

def write_klass_file(filename, info, depends)
  # Write the new file
  File.open(filename, "w+") do |file|
    file.puts "require \"./all\""

    depends.uniq.each do |r|
      file.puts "require \"./#{r}\""
    end

    file.puts ""

    file.puts "module Kube::Resource"
    info[:contents].each do |line|
      file.puts sub_line(line)
    end
    file.puts "end"
  end
end

def klass_depends(info, klasses) : Array(String)
  # puts "\tFinding depends for #{info[:name]}"
  depends = Array(String).new

  info[:contents].each do |line|
    klasses.sort.each do |klass|
      next if info[:name] == klass
      next if line =~ /^\s?#/
      if line =~ /\b#{klass}\b/
        depends << klass.underscore
      end
    end
  end

  depends
end

def format_files
  puts "Formating"
  Dir.open(MODELS_DIR).children.sort.each do |ver|
    all_temp = File.join(MODELS_DIR, ver, "all.temp")
    all_file = File.join(MODELS_DIR, ver, "all.cr")
    contents = File.read_lines all_temp

    start_index = contents.index("require \"json\"")
    if start_index.nil?
      raise "Unable to find start of file: #{all_file}"
    end

    start_index = start_index + 1
    contents.delete_at(0, start_index)

    data = find_klasses(contents)
    klass_info = data[:klass_info]

    klasses = klass_info.keys

    # Write each class to its own file
    klass_info.each do |klass, info|
      puts "Processing #{klass.klassify}"
      filename = File.join(MODELS_DIR, ver, "#{info[:name].underscore}.cr")

      # Identify any depends
      depends = klass_depends(info, klasses)
      write_klass_file(filename, info, depends)
    end

    first_klass = contents.index { |l| l =~ /^class/ }
    if first_klass.nil?
      raise "Unable to find a class in: #{all_file}"
    end

    first_klass = first_klass - 1
    contents.delete_at(first_klass, (contents.size - first_klass))

    File.open(all_file, "w+") do |file|
      file.puts "require \"json\""
      file.puts ""
      file.puts "module Kube::Resource"

      data[:alias_info].each do |k, v|
        v[:contents].each do |line|
          file.puts sub_line(line)
        end
      end
      file.puts "end"
    end

    `crystal tool format`
  end
end

def sub_line(line)
  KLASS_ALIASES.each do |k, v|
    line = line.gsub(k, v)
  end
  line.gsub("::Class", "")
end

parse_schema
format_files
