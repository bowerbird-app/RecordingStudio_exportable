# frozen_string_literal: true

require "test_helper"

class HomeTopicsFilterTest < ActionDispatch::IntegrationTest
  test "topics created_at date range filters the visible rows" do
    user = User.find_or_create_by!(email: "topics-filter@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in user

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
    assert_select "section#topics"
    assert_select "section#topics h2", text: "Topics"
    assert_select "section#topics", text: /Visible Topic/
    assert_select "section#topics", text: /Hidden Topic/, count: 0
    assert_select "section#topics", text: /Created at/
    assert_select "form[action='#{root_path(anchor: "topics")}']", minimum: 1
    assert_select "section#topics input[name=topic]"
    assert_select "section#topics input[name=article]"
    assert_select "section#topics a[href='#{root_path(anchor: "topics")}']", text: "Reset"
  end

  test "topics text filters keep query param names and reset clears them" do
    user = User.find_or_create_by!(email: "topics-text-filter@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in user

    dashboard = DemoDashboard.create!(name: "Topics Text Filter Dashboard")
    RecordingStudio.root_recording_for(dashboard)

    author = Author.create!(name: "Text Filter Author", bio: "")
    matching_article = Article.create!(title: "Walkthrough Article", body: "Body", author: author)
    other_article = Article.create!(title: "Other Article", body: "Body", author: author)
    Topic.create!(article: matching_article, name: "Exports")
    Topic.create!(article: other_article, name: "Hidden Topic")

    get root_path, params: { topic: "Exports", article: "Walkthrough" }

    assert_response :success
    assert_select "section#topics input[name=topic][value=Exports]"
    assert_select "section#topics input[name=article][value=Walkthrough]"
    assert_select "section#topics", text: /Exports/
    assert_select "section#topics", text: /Hidden Topic/, count: 0

    get root_path(anchor: "topics")

    assert_response :success
    assert_select "section#topics input[name=topic][value=Exports]", count: 0
    assert_select "section#topics input[name=article][value=Walkthrough]", count: 0
    assert_select "section#topics input[name=topic]"
    assert_select "section#topics input[name=article]"
  end

  test "a topic row shows one created-at timestamp" do
    user = User.find_or_create_by!(email: "topics-created-at@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in user

    dashboard = DemoDashboard.create!(name: "Topics Created At Dashboard")
    RecordingStudio.root_recording_for(dashboard)
    author = Author.create!(name: "Created At Author", bio: "")
    first_article = Article.create!(title: "First Created At Article", body: "Body", author: author)
    second_article = Article.create!(title: "Second Created At Article", body: "Body", author: author)
    Topic.create!(
      article: first_article,
      name: "Shared Topic",
      created_at: Time.zone.local(2026, 6, 18, 9, 0, 0),
      updated_at: Time.zone.local(2026, 6, 18, 9, 0, 0)
    )
    Topic.create!(
      article: second_article,
      name: "Shared Topic",
      created_at: Time.zone.local(2026, 6, 18, 11, 0, 0),
      updated_at: Time.zone.local(2026, 6, 18, 11, 0, 0)
    )

    get root_path

    assert_response :success
    assert_select "h1", text: "Exports"
    assert_includes response.body, "Download a CSV from the pages you can open."
    refute_includes response.body, ">Demo<"
    assert_select "section#topics tr", text: /Shared Topic/ do |rows|
      assert_equal 1, rows.sum { |row| row.css("time").size }
    end
    assert_select "section#topics td", text: "First Created At Article - Created At Author, Second Created At Article - Created At Author"
  end
end
