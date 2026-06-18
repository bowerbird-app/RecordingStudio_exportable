# frozen_string_literal: true

require "test_helper"

class ExportDefinitionTest < Minitest::Test
  FakeContext = Struct.new(:recordable_type, :recordable)

  def test_definition_normalizes_columns_and_validates_context
    definition = RecordingStudioExportable::ExportDefinition.new(
      key: "demo.people",
      context_types: ["DemoDashboard"],
      columns: [
        :name,
        { key: :enabled, label: "Enabled?", value: :enabled },
        { "Score" => ->(row) { row[:score] } }
      ]
    ) { [] }

    assert_equal ["name", "enabled", "score"], definition.columns.map(&:key)
    assert_equal ["Name", "Enabled?", "Score"], definition.headers
    assert definition.validate_context!(FakeContext.new("DemoDashboard", Object.new))
    assert_raises(RecordingStudioExportable::ExportNotAllowedForContext) do
      definition.validate_context!(FakeContext.new("Other", Object.new))
    end
  end

  def test_selected_columns_reject_unapproved_columns
    definition = RecordingStudioExportable::ExportDefinition.new(
      key: "demo.people",
      columns: [:name, :email],
      default_columns: [:name]
    ) { [] }

    assert_equal ["name"], definition.columns_for(nil).map(&:key)
    assert_equal ["email"], definition.columns_for({ columns: ["email"] }).map(&:key)
    assert_raises(RecordingStudioExportable::InvalidExportColumns) do
      definition.columns_for({ columns: ["admin"] })
    end
  end

  def test_allowed_attributes_are_scoped_and_validate_requested_attributes
    word_count = ->(article) { article.body.to_s.split.size }
    definition = RecordingStudioExportable::ExportDefinition.new(
      key: "demo.articles",
      columns: [:title],
      allowed_attributes: {
        articles: [
          { key: :title, label: "Title", value: :title },
          { key: :word_count, label: "Word count", value: word_count }
        ]
      }
    ) { [] }

    assert_equal ["articles"], definition.allowed_attribute_scopes
    assert_equal ["title", "word_count"], definition.allowed_attribute_keys_for(:articles)
    assert_equal ["Title", "Word count"], definition.allowed_attributes_for("articles").map(&:label)
    assert definition.validate_attributes!(articles: [:title])
    assert definition.validate_attributes!("articles" => { "attributes" => ["word_count"] }, columns: ["title"])

    assert_raises(RecordingStudioExportable::InvalidExportAttributes) do
      definition.validate_attributes!(articles: [:body])
    end
    assert_raises(RecordingStudioExportable::InvalidExportAttributes) do
      definition.validate_attributes!(comments: [:body])
    end
  end

  def test_requires_callable_resolver_and_columns
    assert_raises(RecordingStudioExportable::InvalidExportDefinition) do
      RecordingStudioExportable::ExportDefinition.new(key: "demo.people", columns: [:name])
    end

    assert_raises(RecordingStudioExportable::InvalidExportDefinition) do
      RecordingStudioExportable::ExportDefinition.new(key: "demo.people") { [] }
    end
  end
end
