# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Dummy Topics filters on `/` use FlatPack `TextInput` for topic and article,
  and a ghost `Button` for Reset, with the same query param names.

## 0.5.9 - 2026-11-02

### Changed
- The dummy home page uses FlatPack inputs and a Reset button. The missing
  export link page no longer repeats the expired-link title.
- Docs pages drop the extra page wrapper and keep the sidebar shell.
- README and dummy README describe this gem, not a template.

### Upgrade notes
- Hosts that copied the English `tokens.not_found` strings get new defaults:
  "Link not found" and "That export link is missing". Override the locale
  keys to keep the old wording.

## 0.5.8 - 2026-11-02

### Changed
- **Breaking.** A corrupt `config/recording_studio_exportable.yml` fails boot.
  A missing file is skipped.
- **Breaking.** Export buttons and filter sanitizing no longer hide unexpected
  errors. A gem `Error` still hides the button.
- **Breaking.** The default actor resolver is `Current.actor`. It no longer
  falls back to `controller.current_user`. Set `config.current_actor` when
  the host resolves the actor another way. `resolve_actor` is the one lookup.
- Capability export keys are read in one place.
- A database error while marking the export log failed is logged. The
  original export error is still raised. Any other error from that status
  write is raised too.

### Upgrade notes
- Fix invalid exportable YAML instead of relying on a silent skip.
- Hosts that relied on the default `controller.current_user` fallback must
  set `config.current_actor`. Call `current_user` in that lambda when it is
  public. Do not use `send`.

## 0.5.7 - 2026-11-02

### Changed
- **Breaking.** `issue_trusted_token` requires
  `RecordingStudioAccessible.authorized?` with role `:view`.
- **Breaking.** `export_from_token` requires `actor:`. The actor must be the
  token's actor and still be allowed to view the context recording. That
  check happens before the token is consumed, so a rejected redeem leaves
  the token in place. A custom token store must implement `read` as well as
  `write` and atomic `consume`.
- The dummy trusted export source is `RecordingStudioExportable`.
- The dummy root switcher uses Root Switchable's access check.

### Upgrade notes
- Pass `actor:` to `export_from_token`. The exports controller passes
  `export_actor`.
- Issue tokens only for actors who can view the context recording.
- Allow `RecordingStudioExportable` in `trusted_export_sources` when using the
  dummy issuer, or set your own source string.
- Remove a host `access_check` that always returns true if it was copied from
  the dummy. The default checks view access.
## 0.5.6 - 2026-11-02

### Changed
- **Breaking.** A finished export records history with
  `@context_recording.log_event!` and idempotency key `export:#{export_log.id}`.
  The `Event.create!` fallbacks are gone.
- **Breaking.** If the export log cannot be created, the export fails.
  `ExportLog.create!` raises on a database error. The exported event is
  written before the log is marked completed, so a history failure marks
  the log failed.

### Upgrade notes
- Read the exported event from the context recording. Do not insert
  `RecordingStudio::Event` rows for exports.
- An export now needs a successful `ExportLog` insert. A database error
  during that insert fails the export and writes no exported event.
- Rescue a failed `log_event!` if a host must keep the CSV after history
  fails. The export log stays failed in that case.

## 0.5.5 - 2026-11-02

### Changed
- **Breaking.** Export logs store the chosen columns in `selected_columns`.
  A new migration renames `recording_studio_exportable_export_logs.attributes`
  to `selected_columns`. The request parameter is still `attributes`.

### Upgrade notes
- Copy `db/migrate/20261102120000_rename_export_log_attributes_to_selected_columns.rb`
  into the host and run `bin/rails db:migrate`.
- Read `selected_columns` instead of `attributes` on `ExportLog`.
## 0.5.4 - 2026-11-02

### Removed
- **Breaking.** Template services `ExampleService` and `BaseService`, the
  `Hooks` API (`extend_model`, `extend_controller`, and the engine
  class_eval loops), `RecordingStudio::Capabilities::Exportable.enabled`,
  the `RecordingStudio::Exportable::Capabilities::Exportable` alias, and
  the error aliases `UnknownExportDefinition`, `AuthorizationError`, and
  `RowLimitExceeded`.
- **Breaking.** Configuration aliases `default_row_limit`, `export`, and
  `export_definition`.

### Upgrade notes
- Call `register_export` and `export_definition_for`. Set `max_rows` instead
  of `default_row_limit`, including in `config/recording_studio_exportable.yml`
  and `config.x.recording_studio_exportable`. `merge!` raises `ArgumentError`
  when those removed keys are still present, including at boot.
- Enable a recordable with `include RecordingStudio::Capabilities::Exportable.to(...)`.
- Rescue `UnknownExportKey`, `NotAuthorized`, and `ExportTooLarge`.
- Delete host calls to `RecordingStudioExportable::Hooks`,
  `configuration.hooks`, and `RecordingStudioExportable::Services`.
## 0.5.3 - 2026-11-02

### Changed
- Development and test dependencies include `minitest-mock`. Root tests use
  that `Object#stub` instead of a local compatibility patch.
- Root tests save and restore exportable configuration through `configure`
  instead of replacing the configuration object.
## 0.5.2 - 2026-11-02

### Changed
- CI, the dummy test rake default, and the dummy database names use
  `recording_studio_exportable_test` (development
  `recording_studio_exportable_development`, production primary
  `recording_studio_exportable_production`).
- Removed the unused `test/dummy/.github` workflow and Dependabot config.
  They never ran from the gem repository.
## 0.5.1 - 2026-11-02

### Removed
- Template leftovers: `UPDATE_SUMMARY.md`, `MIGRATION_NOTES.md`, the
  `docs/recording_studio_exportable/` reference set, `bin/rename_gem`, the
  rename verification suite and its rake tasks, `test_codespaces_setup.sh`,
  and unused dummy scaffold (`install_page.html`, `hello_controller.js`, and
  the makeup artist keep file).
- Tracked SimpleCov output under `coverage/` and `test/dummy/coverage/`.
  Both paths are gitignored. `docs/TOKEN_EXPORTS.md` and the API cheatsheet
  stay.

## [0.5.0] - 2026-10-29

### Changed
- Allow Recording Studio `>= 6.1.0, < 7`. Development and dummy pins are core
  `v6.3.0` and FlatPack `v0.1.329`. Dummy companion pins are Accessible
  `v0.24.0`, Trashable `v0.12.0`, Metrics `v0.7.0`, Cache `v0.6.0`, and
  Root Switchable `v0.11.0`.
- Engine controllers use `recording_studio_layout`. Token error views set
  `content_for :title`, `:subtitle`, and `:page_nav_right` instead of
  `recording_studio_page_nav`.

### Upgrade notes
- Pin Recording Studio `>= 6.1` (dummy uses `v6.3.0`) and FlatPack
  `>= 0.1.315` (dummy uses `v0.1.329`). No schema change.

## [0.4.0] - 2026-10-13

### Added
- English Rails I18n keys for non-view interface copy under
  `recording_studio.exportable.errors` (`not_available`, `request_invalid`,
  `format_blank`) in `config/locales/en.yml`
- Dummy always-loaded host override fixture for the rarely shown
  `errors.not_available` key (`test/dummy/config/locales/recording_studio_exportable_host.en.yml`)
  as a real boot-order guard
- Render-level tests for the default Export CSV button label, helper
  `text:` / `unauthorized_text:` variants, controller plain responses, and
  ExportLog format validation (English `errors.details`, French
  `full_messages`, and host override)

### Changed
- Export controller plain-text responses (`Export is not available`,
  `Export request is invalid`) resolve through `t(..., default: ...)`
- ExportLog blank-format validation keeps a String error type and passes the
  translated string as that type (English output unchanged). In non-English
  locales, `errors.details` carries the translated string
- Every existing `t(...)` call for exportable interface copy now passes an
  English `default:` so a host locale with no fallback never shows
  "translation missing"

### Upgrade notes
- No migration or host code change is required for English.
- To translate or override the new error strings, add keys under
  `recording_studio.exportable.errors` in the host's `config/locales`.
- English output remains byte-identical to 0.3.0. Non-English locales that
  override `errors.format_blank` will see the translated string in
  `errors.details` (String type, same as main).

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

[0.5.0]: https://github.com/bowerbird-app/recording_studio_exportable/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/bowerbird-app/recording_studio_exportable/releases/tag/v0.4.0
[0.3.0]: https://github.com/bowerbird-app/recording_studio_exportable/releases/tag/v0.3.0
[0.2.1]: https://github.com/bowerbird-app/recording_studio_exportable/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/bowerbird-app/recording_studio_exportable/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/bowerbird-app/recording_studio_exportable/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/bowerbird-app/recording_studio_exportable/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/recording_studio_exportable/releases/tag/v0.1.0
