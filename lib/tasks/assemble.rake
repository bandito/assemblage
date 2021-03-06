require 'find'
unless defined?(RAILS_ROOT)
  RAILS_ROOT = ENV['RAILS_ROOT']
end

require 'grit'

namespace :assemble do

  desc "Compile both js and css files"
  task :all => [ :js, :css ]

  desc "Compile js files"
  task :js do
    if asset_changed?(:javascripts)
      paths = get_top_level_directories("public/javascripts")
      targets = []
      paths.each do |bundle_directory|
        bundle_name = File.basename(bundle_directory)
        files = recursive_file_list(bundle_directory, ".js")
        next if files.empty? || bundle_name == "dev"

        target = execute_closure(files, bundle_name)

        targets << target
      end

      targets.each do |target|
        puts "=> Assembled JavaScript at: #{target}"
      end
      write_id(:javascripts)
    end
  end

  desc "Compile css files"
  task :css do
    if asset_changed?(:stylesheets)
      paths = get_top_level_directories("public/stylesheets")
      targets = []

      paths.each do |bundle_directory|
        bundle_name = File.basename(bundle_directory)
        files = recursive_file_list(bundle_directory, ".css")

        next if files.empty? || bundle_name == 'dev'

        bundle = ""

        files.each do |file_path|
          bundle << File.read(file_path) << "\n"
        end

        target = execute_yui_compressor(bundle, bundle_name)

        targets << target
      end

      targets.each do |target|
        puts "=> Assembled CSS at: #{target}"
      end
      write_id(:stylesheets)
    end

  end

  desc "Assemblage asset building summary"
  task :help do
    puts <<-HELP
    This is an asset building recipe based on http://github.com/voxxit/assemblage
    As an added feature, everytime js/css files are compiled assemblage stores the
    commit id. This way assets are compiled only once and not every time.
    HELP
  end
  private

  def execute_closure(files, bundle_name)
    jar = File.join(File.dirname(__FILE__), "..", "..", "bin", "closure-compiler.jar")
    target = File.join(RAILS_ROOT ,"public/javascripts/bundle_#{bundle_name}.js")

    `java -jar #{jar} --js #{files.join(" --js ")} --js_output_file #{target}`

    return target
  end

  def execute_yui_compressor(bundle, bundle_name)
    jar = File.join(File.dirname(__FILE__), "..", "..", "bin", "yui-compressor.jar")
    target = File.join(RAILS_ROOT,"public/stylesheets/bundle_#{bundle_name}.css")
    temp_file = "/tmp/bundle_raw.css"

    File.open(temp_file, 'w') { |f| f.write(bundle) }

    `java -jar #{jar} --line-break 0 #{temp_file} -o #{target}`

    return target
  end

  def recursive_file_list(basedir, ext)
    files = []

    Find.find(basedir) do |path|
      if FileTest.directory?(path)
        if File.basename(path)[0] == ?. # Skip dot directories
          Find.prune
        else
          next
        end
      end

      files << path if File.extname(path) == ext
    end

    files.sort
  end

  def get_top_level_directories(base_path)
    Dir.entries(File.join(RAILS_ROOT, base_path)).collect do |path|
      path = File.join(RAILS_ROOT, "#{base_path}/#{path}")
      
      File.basename(path)[0] == ?. || !File.directory?(path) ? nil : path # not dot directories or files
    end - [nil]
  end

  def asset_hash(for_asset)
    Grit::Repo.new(RAILS_ROOT).log('HEAD', "public/#{for_asset}", :max_count => 1).first.id
  end
  
  def asset_changed?(for_asset)
    path = File.join(RAILS_ROOT, ".assemble_#{for_asset}_hash")
    return true unless File.exists?(path)
    last_git_id = open(path, 'r').read.chomp
    last_git_id != asset_hash(for_asset)
  end

  def write_id(for_asset)
    open(File.join(RAILS_ROOT, ".assemble_#{for_asset}_hash"), 'w') do |f|
      f.write(asset_hash(for_asset) + "\n")
    end
  end

end
