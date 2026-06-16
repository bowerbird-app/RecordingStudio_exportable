# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_exportable.gemspec
gem "devise"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.95"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "recording_studio/v3.0.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "0.3.1"
gemspec

gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
