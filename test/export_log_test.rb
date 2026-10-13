# frozen_string_literal: true

require "test_helper"
require "i18n"
require "securerandom"

class ExportLogTest < Minitest::Test
  HOST_FORMAT_BLANK_LOCALE = File.expand_path("fixtures/exportable_format_blank_host.en.yml", __dir__)

  def test_export_log_exposes_expected_scopes
    source = File.read(File.expand_path("../app/models/recording_studio_exportable/export_log.rb", __dir__))

    assert_includes source, "scope :for_context_recording"
    assert_includes source, "scope :for_actor"
    assert_includes source, "scope :completed"
    assert_includes source, "scope :failed"
  end

  def test_format_validation_avoids_kernel_format_method_conflict
    source = File.read(File.expand_path("../app/models/recording_studio_exportable/export_log.rb", __dir__))

    refute_includes source, "validates :export_key, :content_type, :format, :status, presence: true"
    assert_includes source, "validate :format_value_must_be_present"
    assert_includes source, "self[:format].blank?"
  end

  def test_blank_format_english_error_details_match_main_string_type
    with_engine_locales_loaded do
      log = blank_format_log

      refute log.valid?
      assert_equal [{ error: "can't be blank" }], log.errors.details[:format]
      assert_includes log.errors[:format], "can't be blank"
      assert_includes log.errors.full_messages, "Format can't be blank"
    end
  end

  def test_blank_format_french_full_messages_use_translated_string_type
    with_engine_locales_loaded do
      I18n.backend.store_translations(
        :fr,
        recording_studio: {
          exportable: {
            errors: {
              format_blank: "ne peut pas être vide"
            }
          }
        }
      )

      I18n.with_locale(:fr) do
        log = blank_format_log

        refute log.valid?
        assert_equal [{ error: "ne peut pas être vide" }], log.errors.details[:format]
        assert_includes log.errors.full_messages, "Format ne peut pas être vide"
      end
    end
  end

  def test_blank_format_host_override_wins_as_string_type
    with_engine_locales_loaded(extra_locale_paths: [HOST_FORMAT_BLANK_LOCALE]) do
      assert_equal "HOST format blank",
                   I18n.t("recording_studio.exportable.errors.format_blank", default: "can't be blank")

      log = blank_format_log

      refute log.valid?
      assert_equal [{ error: "HOST format blank" }], log.errors.details[:format]
      assert_includes log.errors.full_messages, "Format HOST format blank"
    end
  end

  private

  def blank_format_log
    RecordingStudioExportable::ExportLog.new(
      id: SecureRandom.uuid,
      export_key: "reports.example",
      content_type: "text/csv",
      status: "pending",
      row_count: 0,
      format: ""
    )
  end

  def with_engine_locales_loaded(extra_locale_paths: [])
    locale_path = File.expand_path("../config/locales/en.yml", __dir__)
    original_load_path = I18n.load_path.dup
    original_backend = I18n.backend
    I18n.backend = I18n::Backend::Simple.new

    I18n.load_path = [locale_path, *extra_locale_paths]
    I18n.reload!
    yield
  ensure
    I18n.backend = original_backend
    I18n.load_path.replace(original_load_path)
    I18n.reload!
  end
end
