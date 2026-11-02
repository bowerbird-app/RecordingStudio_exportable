# frozen_string_literal: true

require "test_helper"

class CiDatabaseNameTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  DATABASE = "recording_studio_exportable_test"

  def test_ci_and_rake_use_the_exportable_database_name
    ci = File.read(File.join(ROOT, ".github/workflows/ci.yml"))
    rakefile = File.read(File.join(ROOT, "Rakefile"))

    assert_includes ci, DATABASE
    assert_includes rakefile, DATABASE
    legacy_database = %w[gem template test].join("_")
    refute_includes ci, legacy_database
    refute_includes rakefile, legacy_database
  end

  def test_dummy_database_yml_drops_template_names
    database = File.read(File.join(ROOT, "test/dummy/config/database.yml"))

    assert_includes database, "recording_studio_exportable_development"
    assert_includes database, DATABASE
    assert_includes database, "recording_studio_exportable_production"
    refute_includes database, "app_development"
    refute_includes database, "app_test"
    refute_includes database, "dummy_production\n"
  end

  def test_dummy_github_workflow_is_gone
    refute File.exist?(File.join(ROOT, "test/dummy/.github"))
  end
end
