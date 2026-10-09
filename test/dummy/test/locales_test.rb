# frozen_string_literal: true

require "test_helper"

class LocalesTest < ActiveSupport::TestCase
  test "rails i18n load path includes the exportable gem english locale file" do
    locale_path = RecordingStudioExportable::Engine.root.join("config/locales/en.yml").to_s

    assert_includes I18n.load_path.map { |path| File.expand_path(path) }, File.expand_path(locale_path)
    assert_equal "Export CSV", I18n.t("recording_studio.exportable.buttons.export_csv", raise: true)
  end

  test "engine does not append i18n load path in an initializer" do
    engine_source = File.read(RecordingStudioExportable::Engine.root.join("lib/recording_studio_exportable/engine.rb"))

    refute_includes engine_source, "i18n.load_path"
    refute_includes engine_source, "I18n.load_path"
  end
end
