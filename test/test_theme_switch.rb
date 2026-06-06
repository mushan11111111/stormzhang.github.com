require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'open3'

class ThemeSwitchTest < Minitest::Test
  attr_reader :tmpdir, :rakefile_path

  THEME_FILES = {
    "settings.yml" => "theme :\n  name : twitter\n",
    "default.html" => "<!DOCTYPE html>\n<html>\n<body>default layout</body>\n</html>\n",
    "post.html"    => "<div>post layout content</div>\n",
    "page.html"    => "<div>page layout content</div>\n",
  }

  def setup
    @tmpdir = Dir.mktmpdir("jekyll_theme_test_")
    @rakefile_path = File.expand_path(File.join(__dir__, "..", "Rakefile"))

    theme_dir = File.join(@tmpdir, "_includes", "themes", "twitter")
    FileUtils.mkdir_p(theme_dir)
    THEME_FILES.each do |name, content|
      File.write(File.join(theme_dir, name), content)
    end

    layouts_dir = File.join(@tmpdir, "_layouts")
    FileUtils.mkdir_p(layouts_dir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir && File.directory?(@tmpdir)
  end

  def run_theme_switch(theme_name = "twitter")
    stdout_str, stderr_str, status = Open3.capture3(
      {"name" => theme_name},
      "rake", "-f", @rakefile_path, "theme:switch",
      chdir: @tmpdir
    )
    [stdout_str, stderr_str, status]
  end

  def test_switch_generates_layout_files
    _stdout, _stderr, status = run_theme_switch
    assert status.success?, "rake theme:switch should succeed"

    layout_files = Dir.glob(File.join(@tmpdir, "_layouts", "*"))
                       .map { |f| File.basename(f) }
                       .sort
    expected = %w[default.html page.html post.html]
    assert_equal expected, layout_files
  end

  def test_default_layout_has_settings_front_matter
    _stdout, _stderr, status = run_theme_switch
    assert status.success?

    content = File.read(File.join(@tmpdir, "_layouts", "default.html"))

    assert_match(/theme\s*:\s*\n\s*name\s*:\s*twitter/, content,
                 "default.html should embed theme settings.yml as YAML front matter")

    assert_match(/\{% include themes\/twitter\/default\.html %\}/, content,
                 "default.html should reference themes/twitter/default.html")

    assert_match(/\{% include codepiano\/setup %\}/, content,
                 "default.html should include codepiano/setup")
  end

  def test_non_default_layouts_have_correct_structure
    _stdout, _stderr, status = run_theme_switch
    assert status.success?

    %w[post.html page.html].each do |layout_name|
      content = File.read(File.join(@tmpdir, "_layouts", layout_name))

      assert_match(/layout:\s*default/, content,
                   "#{layout_name} front matter should include 'layout: default'")

      assert_match(/\{% include themes\/twitter\/#{Regexp.escape(layout_name)} %\}/, content,
                   "#{layout_name} should reference themes/twitter/#{layout_name}")

      assert_match(/\{% include codepiano\/setup %\}/, content,
                   "#{layout_name} should include codepiano/setup")
    end
  end

  def test_all_generated_layouts_include_theme_reference
    _stdout, _stderr, status = run_theme_switch
    assert status.success?

    Dir.glob(File.join(@tmpdir, "_layouts", "*.html")).each do |filepath|
      filename = File.basename(filepath)
      content = File.read(filepath)

      assert_match(/\{% include themes\/twitter\/#{Regexp.escape(filename)} %\}/, content,
                   "#{filename} must reference its theme source file under themes/twitter/")
    end
  end

  def test_settings_yml_not_copied_to_layouts
    _stdout, _stderr, status = run_theme_switch
    assert status.success?

    refute File.exist?(File.join(@tmpdir, "_layouts", "settings.yml")),
           "settings.yml should NOT be copied to _layouts directory"
  end

  def test_switch_with_blank_name_aborts
    _stdout, stderr, status = Open3.capture3(
      {"name" => ""},
      "rake", "-f", @rakefile_path, "theme:switch",
      chdir: @tmpdir
    )
    refute status.success?, "rake should abort when name is blank"
    assert_match(/name cannot be blank/, stderr)
  end

  def test_switch_with_nonexistent_theme_aborts
    _stdout, stderr, status = Open3.capture3(
      {"name" => "nonexistent_theme"},
      "rake", "-f", @rakefile_path, "theme:switch",
      chdir: @tmpdir
    )
    refute status.success?, "rake should abort when theme directory does not exist"
    assert_match(/directory not found/, stderr)
  end

  def test_switch_task_success_message
    stdout, _stderr, status = run_theme_switch
    assert status.success?
    assert_match(/Theme successfully switched!/, stdout)
  end

  def test_config_yml_not_modified_by_switch
    config_path = File.join(@tmpdir, "_config.yml")
    original_content = "title: Test Blog\n"
    File.write(config_path, original_content)

    _stdout, _stderr, status = run_theme_switch
    assert status.success?

    assert File.exist?(config_path), "_config.yml should still exist"
    assert_equal original_content, File.read(config_path),
                 "_config.yml should remain unchanged by theme:switch"
  end
end