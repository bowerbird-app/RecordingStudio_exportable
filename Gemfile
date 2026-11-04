# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_exportable.gemspec
gem "bcrypt", ">= 3.1.22"
gem "devise", ">= 5.0.4"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.341"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.3.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.24.0"
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.7.2", require: false
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.12.0", require: false
gemspec

gem "crass", ">= 1.0.8"
gem "puma", ">= 7.2.1"
gem "rack", ">= 3.2.8"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "minitest-mock"
  gem "simplecov", require: false
  gem "sqlite3", ">= 2.9.6"
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
