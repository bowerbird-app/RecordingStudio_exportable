# frozen_string_literal: true

require "test_helper"
require "yaml"
require "i18n"

class LocalesTest < Minitest::Test
  BUTTON_KEYS = {
    "export_csv" => "Export CSV"
  }.freeze

  TOKEN_EXPIRED_KEYS = {
    "nav_title" => "Export expired",
    "title" => "Export Expired",
    "subtitle" => "Refresh the original page"
  }.freeze

  TOKEN_NOT_FOUND_KEYS = {
    "nav_title" => "Export expired",
    "title" => "Export Expired",
    "subtitle" => "Refresh the original page"
  }.freeze

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_engine_exposes_config_locales_for_rails_to_load
    locale_path = File.expand_path(File.join(engine_locales_dir, "en.yml"))
    engine_locale_paths = RecordingStudioExportable::Engine.paths["config/locales"].existent.map do |path|
      File.expand_path(path)
    end

    assert_includes engine_locale_paths, locale_path
  end

  def test_engine_does_not_reappend_locales_to_i18n_load_path
    lib_paths = Dir[File.expand_path("../lib/**/*.rb", __dir__)]
    assert_predicate lib_paths, :any?

    lib_paths.each do |path|
      source = File.read(path)

      refute_includes source, "i18n.load_path",
                      "#{path} must not append app.config.i18n.load_path"
      refute_includes source, "I18n.load_path",
                      "#{path} must not append I18n.load_path"
    end
  end

  def test_english_exportable_interface_keys_resolve_without_missing_translations
    with_engine_locales_loaded do
      I18n.with_locale(:en) do
        BUTTON_KEYS.each do |key, english|
          full_key = "recording_studio.exportable.buttons.#{key}"
          translation = I18n.t(full_key, default: nil)

          assert_equal english, translation, "#{full_key} should resolve to #{english.inspect}"
          assert_equal english, I18n.t(full_key, raise: true)
        end

        TOKEN_EXPIRED_KEYS.each do |key, english|
          full_key = "recording_studio.exportable.tokens.expired.#{key}"
          translation = I18n.t(full_key, default: nil)

          assert_equal english, translation, "#{full_key} should resolve to #{english.inspect}"
          assert_equal english, I18n.t(full_key, raise: true)
        end

        TOKEN_NOT_FOUND_KEYS.each do |key, english|
          full_key = "recording_studio.exportable.tokens.not_found.#{key}"
          translation = I18n.t(full_key, default: nil)

          assert_equal english, translation, "#{full_key} should resolve to #{english.inspect}"
          assert_equal english, I18n.t(full_key, raise: true)
        end
      end
    end
  end

  def test_en_yml_nests_keys_under_recording_studio_exportable
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
           .fetch("recording_studio")
           .fetch("exportable")

    assert_equal BUTTON_KEYS, tree.fetch("buttons").transform_keys(&:to_s)
    assert_equal TOKEN_EXPIRED_KEYS, tree.fetch("tokens").fetch("expired").transform_keys(&:to_s)
    assert_equal TOKEN_NOT_FOUND_KEYS, tree.fetch("tokens").fetch("not_found").transform_keys(&:to_s)
  end

  def test_gem_does_not_ship_a_top_level_recording_studio_exportable_locale_namespace
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")

    refute tree.key?("recording_studio_exportable")
  end

  def test_gemspec_does_not_depend_on_internationalization
    gemspec = File.read(File.expand_path("../recording_studio_exportable.gemspec", __dir__))

    refute_includes gemspec, "recording_studio_internationalization"
    refute_includes gemspec, "RecordingStudio_Internationalization"
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def locale_tree(path, locale)
    YAML.safe_load_file(path, aliases: true).fetch(locale)
  end

  # Unit suite does not boot the dummy app. Load gem English only inside this
  # helper and restore I18n.load_path afterward. Host-override coverage lives in
  # test/dummy/test/integration/host_locale_override_test.rb.
  def with_engine_locales_loaded
    locale_path = File.expand_path(File.join(engine_locales_dir, "en.yml"))
    original_load_path = I18n.load_path.dup

    I18n.load_path |= [locale_path]
    I18n.reload!
    yield
  ensure
    I18n.load_path.replace(original_load_path)
    I18n.reload!
  end
end
