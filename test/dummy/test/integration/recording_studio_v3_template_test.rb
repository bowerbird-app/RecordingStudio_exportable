# frozen_string_literal: true

require "test_helper"
require "csv"

class RecordingStudioV3TemplateTest < ActiveSupport::TestCase
  if defined?(RecordingStudioRootSwitchable)
    test "dummy app loads root switchable config and controller support" do
      assert_equal [ "all_workspaces" ], RecordingStudioRootSwitchable.configuration.scopes.keys
      assert_equal :application_layout, RecordingStudioRootSwitchable.configuration.layout
      assert_includes ApplicationController.ancestors, RecordingStudio::RootSwitchable::ControllerSupport
    end
  end

  test "dummy app validates v3 recordable declarations" do
    assert RecordingStudio.validate_recordable_declarations!
    assert_equal [ "Article", "DemoDashboard", "Document", "Workspace" ], RecordingStudio.root_recordable_types.sort
    assert_equal [ "Article" ], RecordingStudio.allowed_parent_types_for("Author")
    assert_equal [ "Article" ], RecordingStudio.allowed_parent_types_for("Topic")
    assert_equal [ "Document" ], RecordingStudio.allowed_parent_types_for("Item")
    assert_equal [ "Workspace", "Folder" ], RecordingStudio.allowed_parent_types_for("Page")
    assert_includes RecordingStudio.allowed_parent_types_for("RecordingStudio::Access"), "DemoDashboard"
    assert_includes RecordingStudio.allowed_parent_types_for("RecordingStudio::Access"), "Article"
    assert_includes RecordingStudio.allowed_parent_types_for("RecordingStudio::Access"), "Document"
  end

  test "dummy app schema includes extracted access and export tables" do
    connection = ActiveRecord::Base.connection

    assert connection.column_exists?(:recording_studio_recordings, :root_recording_id)
    assert connection.table_exists?(:recording_studio_accesses)
    assert connection.table_exists?(:recording_studio_exportable_export_logs)
    refute connection.table_exists?(:recording_studio_access_boundaries)
    refute connection.table_exists?(:recording_studio_device_sessions)
  end

  test "dummy seeds use v3 hierarchy idempotently and restore current actor" do
    Current.actor = nil

    load Rails.root.join("db/seeds.rb").to_s

    workspace = Workspace.find_by!(name: "Studio Workspace")
    accessible_workspace = Workspace.find_by!(name: "Client Workspace")
    private_workspace = Workspace.find_by!(name: "Private Workspace")
    folder = Folder.find_by!(name: "Product Docs")
    page = Page.find_by!(title: "Getting Started")
    demo_dashboard = DemoDashboard.find_by!(name: "Export Demo Dashboard")
    document = Document.find_by!(title: "Export Governance Handbook")
    document_item = Item.find_by!(document: document, name: "Owner")
    article = Article.find_by!(title: "Recording Studio Export Walkthrough")
    author = Author.find_by!(name: "Ava Editor")
    user = User.find_by!(email: "admin@admin.com")
    viewer_user = User.find_by!(email: "viewer@admin.com")
    root_recording = RecordingStudio::Recording.find_by!(recordable: workspace)
    accessible_root_recording = RecordingStudio::Recording.find_by!(recordable: accessible_workspace)
    private_root_recording = RecordingStudio::Recording.find_by!(recordable: private_workspace)
    folder_recording = RecordingStudio::Recording.find_by!(recordable: folder)
    page_recording = RecordingStudio::Recording.find_by!(recordable: page)
    demo_dashboard_recording = RecordingStudio::Recording.find_by!(recordable: demo_dashboard)
    document_recording = RecordingStudio::Recording.find_by!(recordable: document)
    document_item_recording = RecordingStudio::Recording.find_by!(recordable: document_item)
    article_recording = RecordingStudio::Recording.find_by!(recordable: article)
    author_recording = RecordingStudio::Recording.find_by!(recordable: author)

    assert_nil Current.actor
    assert_nil root_recording.parent_recording_id
    assert_nil accessible_root_recording.parent_recording_id
    assert_nil private_root_recording.parent_recording_id
    assert_nil demo_dashboard_recording.parent_recording_id
    assert_nil document_recording.parent_recording_id
    assert_nil article_recording.parent_recording_id
    assert_equal document_recording, document_item_recording.parent_recording
    assert_equal article_recording, author_recording.parent_recording
    assert_equal root_recording, folder_recording.parent_recording
    assert_equal root_recording, folder_recording.root_recording
    assert_equal folder_recording, page_recording.parent_recording
    assert_equal root_recording, page_recording.root_recording
    assert_equal 6, demo_dashboard.demo_api_requests.count
    assert_equal 2, Article.count
    assert_equal 1, Document.count
    assert_equal 8, Item.count
    assert_operator Author.count, :>=, 2
    assert_equal 100, Topic.count
    assert_equal "Recording Studio Export Walkthrough", article.title
    assert_equal "Ava Editor", article.author.name
    assert_equal 3, Workspace.count
    assert RecordingStudioAccessible.authorized?(actor: user, recording: demo_dashboard_recording, role: :view)
    assert RecordingStudioAccessible.authorized?(actor: user, recording: demo_dashboard_recording, role: :admin)
    assert RecordingStudioAccessible.authorized?(actor: user, recording: document_recording, role: :admin)
    assert RecordingStudioAccessible.authorized?(actor: user, recording: article_recording, role: :view)
    assert RecordingStudioAccessible.authorized?(actor: viewer_user, recording: demo_dashboard_recording, role: :view)
    refute RecordingStudioAccessible.authorized?(actor: viewer_user, recording: document_recording, role: :view)
    assert RecordingStudioAccessible.authorized?(actor: viewer_user, recording: article_recording, role: :view)
    refute RecordingStudioAccessible.authorized?(actor: viewer_user, recording: article_recording, role: :admin)
    assert_equal 1, RecordingStudioAccessible.access_recordings_for_actor(recording: demo_dashboard_recording, actor: user).count
    assert_equal 1, RecordingStudioAccessible.access_recordings_for_actor(recording: article_recording, actor: user).count

    article_export = RecordingStudioExportable.export(
      context_recording: demo_dashboard_recording,
      actor: user,
      export_key: "recording_studio_article_export"
    )
    article_topics_export = RecordingStudioExportable.export(
      context_recording: demo_dashboard_recording,
      actor: viewer_user,
      export_key: "recording_studio_article_topics_authors_export"
    )
    document_items_export = RecordingStudioExportable.export(
      context_recording: document_recording,
      actor: user,
      export_key: "recording_studio_document_items_export"
    )
    topics_export = RecordingStudioExportable.export(
      context_recording: demo_dashboard_recording,
      actor: user,
      export_key: "recording_studio_topics_articles_export"
    )
    topics_with_article_author_attribute = RecordingStudioExportable.export(
      context_recording: demo_dashboard_recording,
      actor: user,
      export_key: "recording_studio_topics_articles_export",
      attributes: {
        columns: ["topic_name", "article_titles"],
        topics: ["name"],
        articles: ["title_with_author"]
      }
    )
    filtered_topics_export = RecordingStudioExportable.export(
      context_recording: demo_dashboard_recording,
      actor: user,
      export_key: "recording_studio_topics_articles_export",
      filters: { topic: "Incident response", article: "Walkthrough" }
    )

    assert_equal 2, article_export.row_count
    assert_equal "articles.csv", article_export.filename
    assert_equal 8, document_items_export.row_count
    assert_equal 100, article_topics_export.row_count
    assert_equal "articles-topics-authors.csv", article_topics_export.filename
    assert_equal 90, topics_export.row_count
    assert_equal "topics-articles.csv", topics_export.filename
    assert_equal 90, topics_with_article_author_attribute.row_count
    assert_equal 1, filtered_topics_export.row_count
    assert_equal 3, CSV.parse(article_export.data, headers: true).headers.count
    assert_equal 8, CSV.parse(document_items_export.data, headers: true).length
    assert_equal 100, CSV.parse(article_topics_export.data, headers: true).length
    assert_equal 90, CSV.parse(topics_export.data, headers: true).length
    assert_includes CSV.parse(topics_export.data, headers: true).first.fetch("Articles"), " - "
    assert_equal 1, CSV.parse(filtered_topics_export.data, headers: true).length

    assert_raises(RecordingStudioExportable::InvalidExportColumns) do
      RecordingStudioExportable.export(
        context_recording: demo_dashboard_recording,
        actor: user,
        export_key: "recording_studio_topics_articles_export",
        attributes: { columns: ["topic_name", "topic_created_at"] }
      )
    end

    assert_raises(RecordingStudioExportable::NotAuthorized) do
      RecordingStudioExportable.export(
        context_recording: document_recording,
        actor: viewer_user,
        export_key: "recording_studio_document_items_export"
      )
    end

    assert_no_difference -> { User.count } do
      assert_no_difference -> { RecordingStudio::Recording.count } do
        load Rails.root.join("db/seeds.rb").to_s
      end
    end
    assert_nil Current.actor
  ensure
    Current.actor = nil
  end
end
