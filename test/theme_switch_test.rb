require_relative 'test_helper'

class TestThemeSwitch < Minitest::Test
  include ThemeTestHelper

  TWITTER_SETTINGS_YML = "theme :\n  name : twitter\n"

  TWITTER_THEME_FILES = {
    'settings.yml' => TWITTER_SETTINGS_YML,
    'default.html' => '<html><body>{{ content }}</body></html>',
    'post.html'    => '<div class="post">{{ content }}</div>',
    'page.html'    => '<div class="page">{{ content }}</div>',
    'index.html'   => '<div class="index">{{ content }}</div>'
  }.freeze

  def teardown
    teardown_theme_sandbox
  end

  def test_switch_with_blank_name_aborts
    setup_theme_sandbox('twitter', TWITTER_THEME_FILES)

    error = assert_raises(SystemExit) do
      invoke_theme_switch(name: '')
    end
    assert_match(/name cannot be blank/, error.message)
  end

  def test_switch_with_nonexistent_theme_directory_aborts
    setup_theme_sandbox('twitter', TWITTER_THEME_FILES)

    error = assert_raises(SystemExit) do
      invoke_theme_switch(name: 'nonexistent-theme')
    end
    assert_match(/directory not found/, error.message)
  end

  def test_switch_with_missing_layouts_directory_aborts
    @original_dir = Dir.pwd
    @tmpdir = Dir.mktmpdir('jekyll-theme-test')

    themes_dir = File.join(@tmpdir, '_includes', 'themes', 'twitter')
    FileUtils.mkdir_p(themes_dir)
    TWITTER_THEME_FILES.each do |filename, content|
      File.write(File.join(themes_dir, filename), content)
    end

    Dir.chdir(@tmpdir)
    load_rakefile

    error = assert_raises(SystemExit) do
      invoke_theme_switch(name: 'twitter')
    end
    assert_match(/directory not found/, error.message)

    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
    ENV.delete('name')
  end

  def test_switch_generates_layout_files_for_all_theme_templates
    setup_theme_sandbox('twitter', TWITTER_THEME_FILES)

    invoke_theme_switch(name: 'twitter')

    expected_layouts = %w[default.html post.html page.html index.html]
    actual_layouts = layout_filenames
    expected_layouts.each do |layout|
      assert_includes(actual_layouts, layout,
        "Expected _layouts/#{layout} to be generated after theme switch")
    end
  end

  def test_switch_settings_yml_is_not_generated_as_layout
    setup_theme_sandbox('twitter', TWITTER_THEME_FILES)

    invoke_theme_switch(name: 'twitter')

    refute_includes(layout_filenames, 'settings.yml',
      "settings.yml should not be generated as a layout file")
  end

  def test_switch_default_layout_contains_settings_yml_in_front_matter
    setup_theme_sandbox('twitter', TWITTER_THEME_FILES)

    invoke_theme_switch(name: 'twitter')

    content = read_layout('default.html')
    refute_nil content, "default.html layout should exist"

    front_matter = content[/^---\n(.+?)\n---/m, 1]
    refute_nil front_matter, "default.html should contain YAML front matter"

    assert_match(/theme\s*:/, front_matter,
      "default.html front matter should contain theme key from settings.yml")
    assert_match(/name\s*:\s*twitter/, front_matter,
      "default.html front matter should contain theme name from settings.yml")
  end

  def test_switch_non_default_layouts_use_default_layout
    setup_theme_sandbox('twitter', TWITTER_THEME_FILES)

    invoke_theme_switch(name: 'twitter')

    %w[post.html page.html index.html].each do |layout_file|
      content = read_layout(layout_file)
      refute_nil content, "_layouts/#{layout_file} should exist"

      front_matter = content[/^---\n(.+?)\n---/m, 1]
      refute_nil front_matter, "_layouts/#{layout_file} should contain YAML front matter"

      assert_match(/layout:\s*default/, front_matter,
        "_layouts/#{layout_file} front matter should specify 'layout: default'")
    end
  end

  def test_switch_default_layout_does_not_use_layout_default
    setup_theme_sandbox('twitter', TWITTER_THEME_FILES)

    invoke_theme_switch(name: 'twitter')

    content = read_layout('default.html')
    front_matter = content[/^---\n(.+?)\n---/m, 1]
    refute_match(/layout:\s*default/, front_matter,
      "default.html should NOT contain 'layout: default' in its front matter")
  end

  def test_switch_all_layouts_include_codepiano_setup
    setup_theme_sandbox('twitter', TWITTER_THEME_FILES)

    invoke_theme_switch(name: 'twitter')

    %w[default.html post.html page.html index.html].each do |layout_file|
      content = read_layout(layout_file)
      assert_includes(content, '{% include codepiano/setup %}',
        "_layouts/#{layout_file} should include codepiano/setup")
    end
  end

  def test_switch_all_layouts_reference_correct_theme_includes
    setup_theme_sandbox('twitter', TWITTER_THEME_FILES)

    invoke_theme_switch(name: 'twitter')

    %w[default.html post.html page.html index.html].each do |layout_file|
      content = read_layout(layout_file)
      expected_ref = theme_include_reference('twitter', layout_file)
      assert_includes(content, expected_ref,
        "_layouts/#{layout_file} should reference #{expected_ref}")
    end
  end

  def test_switch_layouts_correctly_reference_theme_directory
    setup_theme_sandbox('twitter', TWITTER_THEME_FILES)

    invoke_theme_switch(name: 'twitter')

    %w[default.html post.html page.html index.html].each do |layout_file|
      content = read_layout(layout_file)
      assert_includes(content, "{% include themes/twitter/#{layout_file} %}",
        "_layouts/#{layout_file} should reference themes/twitter/#{layout_file}")
    end
  end

  def test_switch_with_custom_theme_name
    custom_settings = "theme :\n  name : custom-theme\n"
    custom_files = {
      'settings.yml' => custom_settings,
      'default.html' => '<custom>{{ content }}</custom>',
      'page.html'    => '<custom-page>{{ content }}</custom-page>'
    }

    setup_theme_sandbox('custom-theme', custom_files)

    invoke_theme_switch(name: 'custom-theme')

    %w[default.html page.html].each do |layout_file|
      content = read_layout(layout_file)
      refute_nil content, "_layouts/#{layout_file} should be generated"
      assert_includes(content, "{% include themes/custom-theme/#{layout_file} %}",
        "_layouts/#{layout_file} should reference themes/custom-theme/#{layout_file}")
    end

    default_content = read_layout('default.html')
    assert_match(/name\s*:\s*custom-theme/, default_content,
      "default.html front matter should contain the custom theme name")
  end

  def test_switch_overwrites_existing_layouts
    setup_theme_sandbox('twitter', TWITTER_THEME_FILES)

    File.write(File.join(@tmpdir, '_layouts', 'default.html'), "old content")

    invoke_theme_switch(name: 'twitter')

    content = read_layout('default.html')
    refute_equal("old content", content,
      "Existing layout files should be overwritten by theme switch")
    assert_includes(content, "{% include themes/twitter/default.html %}",
      "Overwritten layout should contain new theme reference")
  end

  def test_switch_theme_without_settings_yml
    theme_files = {
      'default.html' => '<html>{{ content }}</html>',
      'post.html'    => '<div>{{ content }}</div>'
    }

    setup_theme_sandbox('minimal', theme_files)

    invoke_theme_switch(name: 'minimal')

    content = read_layout('default.html')
    refute_nil content, "default.html should still be generated without settings.yml"

    front_matter_lines = content.lines.select { |l| l.strip == '---' }
    assert_equal(2, front_matter_lines.size,
      "default.html should still have YAML front matter delimiters even without settings.yml")
  end
end
