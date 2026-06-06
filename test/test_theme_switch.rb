require 'minitest/autorun'
require 'fileutils'
require 'yaml'

class TestThemeSwitch < Minitest::Test
  def setup
    @source_dir = File.expand_path('../', __FILE__)
    @test_theme = 'twitter'
    
    @original_files = {}
    @layouts_dir = File.join(@source_dir, '_layouts')
    
    Dir.glob(File.join(@layouts_dir, '*')).each do |file|
      @original_files[file] = File.read(file) if File.file?(file)
    end
  end

  def teardown
    @original_files.each do |file, content|
      File.write(file, content)
    end
  end

  def test_theme_switch_updates_layouts_correctly
    require 'rake'
    load File.join(@source_dir, 'Rakefile')
    
    ENV['name'] = @test_theme
    
    original_stdout = $stdout
    $stdout = StringIO.new
    
    begin
      Rake::Task['theme:switch'].execute
    ensure
      $stdout = original_stdout
    end
    
    verify_layouts_have_correct_theme_reference
  end

  def verify_layouts_have_correct_theme_reference
    expected_include = "{% include themes/#{@test_theme}/"
    
    Dir.glob(File.join(@layouts_dir, '*.html')).each do |layout_file|
      next unless File.file?(layout_file)
      
      content = File.read(layout_file)
      filename = File.basename(layout_file)
      
      if filename.downcase == 'default.html'
        assert_includes content, "theme :", "default.html should contain theme configuration"
        assert_includes content, "name : #{@test_theme}", "default.html should set theme name to #{@test_theme}"
      end
      
      assert_includes content, "#{expected_include}#{filename}", 
        "Layout #{filename} should include reference to #{expected_include}#{filename}"
    end
  end

  def test_theme_settings_in_default_layout
    default_layout = File.join(@layouts_dir, 'default.html')
    content = File.read(default_layout)
    
    yaml_part = content.split('---')[1]
    if yaml_part
      config = YAML.load(yaml_part)
      assert_equal @test_theme, config['theme']['name'], "Theme name should be #{@test_theme}"
    end
  end

  def test_theme_includes_exist
    theme_dir = File.join(@source_dir, '_includes', 'themes', @test_theme)
    
    assert File.directory?(theme_dir), "Theme directory #{theme_dir} should exist"
    
    layout_files = Dir.glob(File.join(@layouts_dir, '*.html')).map { |f| File.basename(f) }
    
    layout_files.each do |layout_file|
      theme_file = File.join(theme_dir, layout_file)
      assert File.exist?(theme_file), "Theme file #{theme_file} should exist"
    end
  end

  def test_theme_switch_does_not_change_config_yml
    config_yml = File.join(@source_dir, '_config.yml')
    original_config = File.read(config_yml)
    
    require 'rake'
    load File.join(@source_dir, 'Rakefile')
    
    ENV['name'] = @test_theme
    
    original_stdout = $stdout
    $stdout = StringIO.new
    
    begin
      Rake::Task['theme:switch'].execute
    ensure
      $stdout = original_stdout
    end
    
    new_config = File.read(config_yml)
    assert_equal original_config, new_config, "_config.yml should not be modified by theme:switch"
  end
end
