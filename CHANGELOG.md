# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-10-09

### Added
- English Rails I18n keys for static interface copy in the gem's own export token
  error views and default export button label (`config/locales/en.yml` under
  `recording_studio.exportable`)
- Dummy integration test proves a test-only host English override fixture
  (appended last to `I18n.load_path` for that test) wins over the gem

### Changed
- Pin RecordingStudio to git tag `v4.2.2` in the gem and dummy Gemfiles.
- Pin RecordingStudio Accessible to git tag `v0.11.1` in the gem and dummy Gemfiles.
- Dummy app applies Accessible 0.8–0.11 migrations (`depends_on_recording_id`, access invitations, string `role`) and seeds grants through `RecordingStudioAccessible.grant_access` and revoke services. `RecordingStudio::Access` is readonly in 0.11.
- Token expired / not found PageNav titles, page titles, and subtitles resolve
  through `t(...)` (English output unchanged)
- Default `recording_studio_export_button` / `recording_studio_export_access_button`
  label resolves through `t("recording_studio.exportable.buttons.export_csv")`
  when callers omit `text:` (English output unchanged)

### Upgrade notes
- No migration or host code change is required for English.
- To translate or override the defaults, add keys under
  `recording_studio.exportable` in the host's `config/locales`.
- The engine relies on Rails' automatic `config/locales` loading. Do not add an
  explicit `i18n.load_path` initializer for this gem.
- Callers that pass `text:` (or `unauthorized_text:`) keep their own labels.

## [0.2.1] - 2026-09-03

Cloud Agent Builds fetch Cursor skills at Build. Warm rebuilds skip provision.

### Added
- Track `.cursor/environment.json`, `.cursor/install.sh`, `.cursor/start.sh`, and `.cursor/fetch-skills.sh`. Cloud Agent Builds fetch RecordingStudio_cursor_plugin through `fetch-skills.sh`. Skills and plugin rules stay gitignored Build output.

### Changed
- `.cursor/install.sh` skips apt, ruby-build, db:prepare, and tailwind when Ruby, bundle, and Postgres are already usable. A skippable provision failure does not fail the Build. Fetch-skills always runs last.

### Upgrade notes
- No host or schema changes. Rebuild the Cloud Agent environment with Draft off so Build loads the pack.

## [0.2.0] - 2026-08-21

### Added
- Hosts enable exports with `include RecordingStudio::Capabilities::Exportable.to(**options)`, a thin wrapper around RecordingStudio 4.2.0 `include_for(:exportable, **options)`.
- Option validation for `export_keys:`, `exports:`, `required_role:`, `max_rows:`, and `formats:` stays in this gem. `install_recordable_methods!` still runs from the mixin include hook.

### Changed
- Require RecordingStudio `~> 4.2` and pin the gem and dummy app to tag `v4.2.0`.
- Dummy recordables now opt in with `include .to`. Installing the gem still does not enable `:exportable`.
- Engine screens use RecordingStudio's shared default layout when the host has not set `config.layout`.
- Dummy Tailwind scans a `vendor/flat_pack` symlink so table padding and other Flatpack utilities load.

### Deprecated
- `RecordingStudio::Capabilities::Exportable.enabled` remains available and calls through to `.to`, but it is no longer the documented host verb.

### Upgrade notes
- Upgrade RecordingStudio to `4.2.0` or newer before installing this release.
- Replace class-method enablement with the include factory on each recordable that should export:

```ruby
class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true

  include RecordingStudio::Capabilities::Exportable.to(
    export_keys: ["reports.example"],
    required_role: :view,
    max_rows: 1_000,
    formats: [:csv]
  )
end
```

- Parent rules stay on `recording_studio_recordable`. `register_capability(:exportable)` still happens at engine boot; do not call it from `.to`.
- `enabled(...)` still works during the transition and prints a deprecation warning. Switch hosts to `include .to`.
- Run `bin/rails generate recording_studio:migrations` and `bin/rails db:migrate` if you are moving a host from RecordingStudio 3.x to 4.2.

## [0.1.2] - 2026-06-30

### Added
- Added trusted export token issuance, storage, consumption, and controller support for trusted export flows.
- Added dummy app documentation and integration coverage for trusted exports and token-based exports.

### Fixed
- Fixed dummy app CI execution so Rails discovers dummy tests without passing an extra test path argument.
- Fixed CI PostgreSQL health checks to use the configured database user and database.
- Fixed CI eager loading for manually registered dummy export definitions by excluding them from the Rails autoloader.

## [0.1.1] - 2026-04-28

### Changed
- Bumped the dummy app FlatPack dependency from `0.1.2` to `0.1.33` and pinned it by tag in `test/dummy/Gemfile`

## [0.1.0] - 2025-12-04

### Added
- Initial release
- Rails mountable engine structure
- PostgreSQL with UUID primary keys support
- TailwindCSS v4 integration
- GitHub Codespaces devcontainer configuration
- Docker Compose setup with PostgreSQL and Redis
- Install generator for host applications
- Comprehensive README and documentation
- Basic test suite with Minitest

[Unreleased]: https://github.com/bowerbird-app/recording_studio_exportable/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/bowerbird-app/recording_studio_exportable/releases/tag/v0.3.0
[0.2.1]: https://github.com/bowerbird-app/recording_studio_exportable/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/bowerbird-app/recording_studio_exportable/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/bowerbird-app/recording_studio_exportable/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/bowerbird-app/recording_studio_exportable/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/recording_studio_exportable/releases/tag/v0.1.0
