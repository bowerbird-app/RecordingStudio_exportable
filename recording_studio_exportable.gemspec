# frozen_string_literal: true

require_relative "lib/recording_studio_exportable/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_exportable"
  spec.version     = RecordingStudioExportable::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_exportable"
  spec.summary     = "CSV export capability addon for Recording Studio"
  spec.description = "Recording Studio addon that registers export definitions and generates authorized in-memory CSV exports."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_exportable"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_exportable/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 3.0"
  spec.add_dependency "recording_studio_accessible", ">= 0.3"
  spec.add_dependency "flat_pack", ">= 0.1.95"
end
