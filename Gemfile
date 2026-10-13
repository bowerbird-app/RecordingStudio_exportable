# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_exportable.gemspec
gem "devise"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.198"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.5.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.17.0"
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.2.0", require: false
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.10.0", require: false
gemspec

gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
  gem "sqlite3"
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
