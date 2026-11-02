# frozen_string_literal: true

require "test_helper"

class DependencyPinsTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_gemspec_floors_match_the_tested_pins
    spec = Gem::Specification.load(File.join(ROOT, "recording_studio_exportable.gemspec"))
    requirements = spec.runtime_dependencies.to_h { |dependency| [dependency.name, dependency.requirement] }

    assert_equal Gem::Requirement.new(">= 0.1.315", "< 0.2"), requirements.fetch("flat_pack")
    assert_equal Gem::Requirement.new("~> 0.24"), requirements.fetch("recording_studio_accessible")
    refute requirements.key?("view_component")
  end

  def test_gemfiles_pin_flatpack_and_root_switchable
    root = File.read(File.join(ROOT, "Gemfile"))
    dummy = File.read(File.join(ROOT, "test/dummy/Gemfile"))

    assert_includes root, 'gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.332"'
    assert_includes dummy, 'gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.332"'
    assert_includes dummy, 'tag: "v0.11.3"'
  end

  def test_locks_keep_view_component_and_record_the_new_pins
    [File.join(ROOT, "Gemfile.lock"), File.join(ROOT, "test/dummy/Gemfile.lock")].each do |path|
      lock = File.read(path)

      assert_includes lock, "view_component (4.20.0)", path
      assert_includes lock, "tag: v0.1.332", path
      assert_includes lock, "flat_pack (0.1.332)", path
      assert_includes lock, "revision: 04bacc3588bb3f7e082fdc3dbe0914e1eb4a4bd4", path
    end

    dummy_lock = File.read(File.join(ROOT, "test/dummy/Gemfile.lock"))
    assert_includes dummy_lock, "tag: v0.11.3"
    assert_includes dummy_lock, "recording_studio_root_switchable (0.11.3)"
    assert_includes dummy_lock, "revision: b367ac8e1bf37ae3029a462f2f6dd6b8b8200110"
  end

  def test_changelog_notes_unlogged_patch_tags_once
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))

    assert_equal 1, changelog.scan("v0.2.2 through v0.2.8").size
    assert_includes changelog, "v0.3.1, and v0.4.1 through v0.4.3"
    refute_includes changelog, "## [0.2.2]"
    refute_includes changelog, "## [0.4.1]"
  end
end
