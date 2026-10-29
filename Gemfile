# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_exportable.gemspec
gem "devise"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.329"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.3.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.24.0"
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.7.0", require: false
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.12.0", require: false
gemspec

gem "puma", ">= 7.2.1"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
  gem "sqlite3", ">= 2.9.6"
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
