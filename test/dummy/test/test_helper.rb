# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"
require "devise"
require "devise/test/integration_helpers"

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers if defined?(Devise::Test::IntegrationHelpers)

  setup do
    host! "localhost"
    Current.reset if defined?(Current)
  end

  teardown do
    Current.reset if defined?(Current)
  end
end
