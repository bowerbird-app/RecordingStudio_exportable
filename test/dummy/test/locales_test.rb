# frozen_string_literal: true

require "test_helper"

class LocalesTest < ActiveSupport::TestCase
  test "rails i18n load path includes the exportable gem english locale file" do
    locale_path = RecordingStudioExportable::Engine.root.join("config/locales/en.yml").to_s

    assert_includes I18n.load_path.map { |path| File.expand_path(path) }, File.expand_path(locale_path)
    assert_equal "Export CSV", I18n.t("recording_studio.exportable.buttons.export_csv", raise: true)
    assert_equal "Back to exports", I18n.t("recording_studio.exportable.tokens.back", raise: true)
    assert_equal "Start a fresh export.", I18n.t("recording_studio.exportable.tokens.not_found.subtitle", raise: true)
    assert_equal "That export link is missing", I18n.t("recording_studio.exportable.tokens.not_found.title", raise: true)
    assert_equal "Export expired", I18n.t("recording_studio.exportable.tokens.expired.title", raise: true)
    refute_equal I18n.t("recording_studio.exportable.tokens.expired.title", raise: true),
                 I18n.t("recording_studio.exportable.tokens.not_found.title", raise: true)
  end

  test "engine lib does not append i18n load path" do
    lib_paths = Dir[RecordingStudioExportable::Engine.root.join("lib/**/*.rb").to_s]
    assert_predicate lib_paths, :any?

    lib_paths.each do |path|
      source = File.read(path)

      refute_includes source, "i18n.load_path", "#{path} must not append app.config.i18n.load_path"
      refute_includes source, "I18n.load_path", "#{path} must not append I18n.load_path"
    end
  end
end
