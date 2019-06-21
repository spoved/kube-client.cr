dir = "lib/kubernetes-json-schema"

SKIP_FILES = ["_definitions.json", "all.json", "intorstring-util-intstr.json", "intorstring.json",
              "quantity-resource.json", "quantity.json"]

Dir.open(dir).children.sort.each do |ver|
  next unless File.directory?(File.join(dir, ver))
  next unless ver =~ /^v(\d+\.\d+\.\d+)$/

  # Minikube ver
  # next unless ver == "v1.14.3"

  api_klass = "V#{$1}".gsub('.', '_')

  out_dir = File.join("./src/kube/models", ver)
  # `rm -rf #{out_dir}` if Dir.exists?(out_dir)

  Dir.mkdir(out_dir) unless Dir.exists?(out_dir)

  Dir.cd(out_dir) do
    files = Array(String).new

    Dir.open(File.join(dir, ver)).children.sort.each do |file|
      next unless file =~ /json$/
      # next if file =~ /customresource|v1/

      next if SKIP_FILES.includes?(file)

      input = File.join(dir, ver, file)
      output = file.chomp(".json") + ".cr"

      files << input

      next if File.exists?(output)

      puts input
      # if !system("quicktype -s schema --lang cr -o #{output} #{input}")
      #   puts "ERROR: Failed to parse file: #{input}"
      # end
    end

    failed = false
    puts "Running big command"
    while !system("quicktype -s schema --lang cr -o all.cr #{files.join(' ')}")
      failed = true
      puts "Dropping #{files.pop}"
    end

    exit 1 if failed
  end

  # break
end
