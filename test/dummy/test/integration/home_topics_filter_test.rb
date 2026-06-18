# frozen_string_literal: true

require "test_helper"

class HomeTopicsFilterTest < ActionDispatch::IntegrationTest
  test "topics created_at date range filters the visible rows" do
    dashboard = DemoDashboard.create!(name: "Topics Filter Dashboard")
    RecordingStudio.root_recording_for(dashboard)

    author = Author.create!(name: "Filter Author", bio: "")
    article = Article.create!(title: "Filter Article", body: "Body", author: author)

    Topic.create!(article: article, name: "Visible Topic", created_at: Time.zone.local(2026, 6, 18, 10, 0, 0), updated_at: Time.zone.local(2026, 6, 18, 10, 0, 0))
    Topic.create!(article: article, name: "Hidden Topic", created_at: Time.zone.local(2026, 6, 16, 10, 0, 0), updated_at: Time.zone.local(2026, 6, 16, 10, 0, 0))

    get root_path, params: {
      topics_created_at_start: "2026-06-18",
      topics_created_at_end: "2026-06-18"
    }

    assert_response :success
    assert_includes response.body, "Visible Topic"
    refute_includes response.body, "Hidden Topic"
    assert_includes response.body, "Created at"
  end
end
