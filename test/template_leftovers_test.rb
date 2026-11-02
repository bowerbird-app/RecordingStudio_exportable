# frozen_string_literal: true

require "test_helper"

class TemplateLeftoversTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  REMOVED = %w[
    UPDATE_SUMMARY.md
    MIGRATION_NOTES.md
    bin/rename_gem
    test/rename_verification_test.rb
    test_codespaces_setup.sh
    test/dummy/install_page.html
    test/dummy/app/javascript/controllers/hello_controller.js
    test/dummy/app/views/makeup_artist/custom_examples/.keep
  ].freeze

  def test_template_files_are_gone
    REMOVED.each do |relative|
      refute File.exist?(File.join(ROOT, relative)), "#{relative} should be deleted"
    end

    docs = Dir.children(File.join(ROOT, "docs"))
    assert_empty docs.grep(/\Arecording_studio_exportable\z/)
    assert_includes docs, "TOKEN_EXPORTS.md"
    assert_includes docs, "recording_studio_exportable_api_cheatsheet.md"
  end

  def test_coverage_reports_are_gitignored_and_untracked
    gitignore = File.read(File.join(ROOT, ".gitignore"))
    rules = gitignore.lines.map(&:strip)

    assert_includes rules, "coverage/"
    assert_includes rules, "test/dummy/coverage/"

    tracked = `git -C #{ROOT} ls-files`.lines.map(&:strip)
    assert_empty tracked.grep(%r{(^|/)coverage/})
  end

  def test_rename_rake_tasks_are_gone
    rakefile = File.read(File.join(ROOT, "Rakefile"))

    refute_includes rakefile, "rename_verification"
    refute_includes rakefile, "rename_gem"
  end

  def test_agent_notes_name_this_gem
    copilot = File.read(File.join(ROOT, ".github/copilot-instructions.md"))
    architect = File.read(File.join(ROOT, ".github/agents/rails_architect.agent.md"))

    legacy_name = %w[Gem Template].join
    refute_includes copilot, legacy_name
    refute_includes architect, legacy_name
    assert_includes copilot, "RecordingStudioExportable"
    assert_includes architect, "RecordingStudioExportable.configure"
  end
end
