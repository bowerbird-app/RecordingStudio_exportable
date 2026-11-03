# frozen_string_literal: true

require "test_helper"

class DependencyPinsTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_gemspec_floors_match_the_tested_pins
    spec = Gem::Specification.load(File.join(ROOT, "recording_studio_exportable.gemspec"))
    requirements = spec.runtime_dependencies.to_h { |dependency| [dependency.name, dependency.requirement] }

    assert_equal Gem::Requirement.new(">= 0.1.315", "< 0.2"), requirements.fetch("flat_pack")
    assert_equal Gem::Requirement.new("~> 0.24"), requirements.fetch("recording_studio_accessible")
    assert_equal Gem::Requirement.new("< 4"), requirements.fetch("csv")
    refute requirements.key?("view_component")
  end
end
