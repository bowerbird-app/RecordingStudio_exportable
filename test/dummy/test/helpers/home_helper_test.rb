# frozen_string_literal: true

require "test_helper"

class HomeHelperTest < ActionView::TestCase
  test "pagination keeps the topics page param and the current filters" do
    pagy = HomeHelper::PageNav.new(
      page: 1,
      pages: 3,
      page_param: :topics_page,
      extra: { "topic" => "Ada" }
    )
    controller.request.define_singleton_method(:query_parameters) { { "article" => "Essay" } }

    url = pagy_url_for(pagy, 2)

    assert_includes url, "topics_page=2"
    assert_includes url, "topic=Ada"
    assert_includes url, "article=Essay"
    assert_includes url, "topics"
  end
end
