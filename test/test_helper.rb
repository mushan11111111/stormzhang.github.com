require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'rake'

PROJECT_ROOT = File.expand_path('..', __dir__)

module ThemeTestHelper
  def setup_theme_sandbox(theme_name, theme_files = {})
    @original_dir = Dir.pwd
    @tmpdir = Dir.mktmpdir('jekyll-theme-test')

    themes_dir = File.join(@tmpdir, '_includes', 'themes', theme_name)
    layouts_dir = File.join(@tmpdir, '_layouts')
    FileUtils.mkdir_p(themes_dir)
    FileUtils.mkdir_p(layouts_dir)

    theme_files.each do |filename, content|
      File.write(File.join(themes_dir, filename), content)
    end

    Dir.chdir(@tmpdir)
    load_rakefile
  end

  def teardown_theme_sandbox
    Dir.chdir(@original_dir) if @original_dir && Dir.pwd != @original_dir
    FileUtils.rm_rf(@tmpdir) if @tmpdir && File.exist?(@tmpdir)
    ENV.delete('name')
  end

  def load_rakefile
    Rake::Task.clear
    verbose_setting = $VERBOSE
    $VERBOSE = nil
    load File.join(PROJECT_ROOT, 'Rakefile')
    $VERBOSE = verbose_setting
  end

  def invoke_theme_switch(name:)
    ENV['name'] = name
    Rake::Task['theme:switch'].reenable
    Rake::Task['theme:switch'].invoke
  end

  def read_layout(filename)
    path = File.join(@tmpdir, '_layouts', filename)
    File.exist?(path) ? File.read(path) : nil
  end

  def layout_filenames
    Dir.glob(File.join(@tmpdir, '_layouts', '*')).map { |f| File.basename(f) }
  end

  def theme_include_reference(theme_name, filename)
    "{% include themes/#{theme_name}/#{filename} %}"
  end
end
