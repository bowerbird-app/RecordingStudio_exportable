# frozen_string_literal: true

require "test_helper"

class DependencyPinsTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_gemspec_floors_match_the_tested_pins
    spec = Gem::Specification.load(File.join(ROOT, "recording_studio_exportable.gemspec"))
    requirements = spec.runtime_dependencies.to_h { |dependency| [dependency.name, dependency.requirement] }

    assert_equal Gem::Requirement.new(">= 0.1.315", "< 1.0"), requirements.fetch("flat_pack")
    assert_equal Gem::Requirement.new(">= 7.0", "< 8.0"), requirements.fetch("recording_studio")
    assert_equal Gem::Requirement.new(">= 0.44.0", "< 1.0"), requirements.fetch("recording_studio_accessible")
    assert_equal Gem::Requirement.new("< 4"), requirements.fetch("csv")
    refute requirements.key?("view_component")
  end

  def test_gemfiles_pin_recording_studio_gems_with_pessimistic_constraints
    root = File.read(File.join(ROOT, "Gemfile"))
    dummy = File.read(File.join(ROOT, "test/dummy/Gemfile"))

    {
      'gem "recording_studio", "~> 7.8", github: "bowerbird-app/RecordingStudio", tag: "v7.8.0"' => [root, dummy],
      'gem "flat_pack", "~> 0.2", github: "bowerbird-app/flatpack", tag: "v0.2.0"' => [root, dummy],
      'gem "recording_studio_accessible", "~> 0.58", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.58.0"' => [root, dummy],
      %(gem "recording_studio_metrics", "~> 0.10",\n    github: "bowerbird-app/RecordingStudio_metrics",\n    tag: "v0.10.0") => [root],
      'gem "recording_studio_metrics", "~> 0.10", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.10.0"' => [dummy],
      %(gem "recording_studio_trashable", "~> 1.3",\n    github: "bowerbird-app/RecordingStudio_trashable",\n    tag: "v1.3.0") => [root],
      'gem "recording_studio_trashable", "~> 1.3", github: "bowerbird-app/RecordingStudio_trashable", tag: "v1.3.0"' => [dummy],
      'gem "recording_studio_api", "~> 1.20", github: "bowerbird-app/RecordingStudio_api", tag: "v1.20.0"' => [root, dummy],
      'gem "recording_studio_icons", "~> 0.5", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.5.0"' => [root, dummy],
      'gem "recording_studio_logs", "~> 0.9", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.9.0"' => [root, dummy],
      'gem "recording_studio_moveable", "~> 6.1", github: "bowerbird-app/RecordingStudio_moveable", tag: "v6.1.0"' => [root, dummy],
      'gem "recording_studio_cache", "~> 0.8", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.8.0"' => [dummy],
      'gem "recording_studio_admin", "~> 2.19", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.19.1"' => [dummy],
      'gem "recording_studio_root_switchable", "~> 0.17", github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.17.0"' => [dummy]
    }.each do |line, sources|
      sources.each { |source| assert_includes source, line }
    end
  end
end
