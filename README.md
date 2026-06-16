# RecordingStudioExportable

CSV export capability addon for RecordingStudio. Host apps register namespaced export definitions, enable the
`:exportable` capability on supported recordables, and stream authorized in-memory CSV downloads.

## What's Included

- **RecordingStudio** gem installed and configured
- **Devise** authentication with a pre-seeded admin user
- **Workspace**, **Folder**, **Page**, **DemoDashboard**, and **DemoApiRequest** recordables seeded into the dummy host app
- **RecordingStudioExportable** export registry, capability wiring, engine POST endpoint, helper, and export logs
- **FlatPack** UI component library for all views
- **Dummy app** (`test/dummy/`) with a FlatPack-based sign-in screen, a simple home page, mounted RecordingStudio routes, and FlatPack's built-in rounded theme enabled by default

The dummy app ships with a starter sidebar documentation shell for authenticated pages. The menu entries in `test/dummy/app/views/layouts/flat_pack/_sidebar.html.erb` and the linked docs pages are intended to be rewritten to suit the addon you are building; the template provides the structure and styling, not final product copy. By default, that starter shell uses FlatPack's built-in rounded theme via the root layout attribute rather than custom Tailwind theme recreation.

## Quick Start

### GitHub Codespaces (Recommended)

1. Click **Code** → **Codespaces** → **Create codespace**
2. Wait for setup to complete
3. Run:
   ```bash
   cd test/dummy
   bin/rails db:setup
   bin/dev
   ```
4. Open port 3000 — you'll land on the dummy app home page and can sign in at `/users/sign_in`

The dummy app is intended as a host-app validation surface for authentication, FlatPack rendering, Tailwind source scanning, and RecordingStudio route wiring.

### Login Credentials

| Field    | Value             |
|----------|-------------------|
| Email    | admin@admin.com   |
| Password | Password          |

The login form is prefilled with these credentials for fast access.

### Useful Routes

- `/` — dummy app home page
- `/users/sign_in` — Devise sign-in page
- `/recording_studio` — redirect to `/` while the mounted RecordingStudio engine remains data/API-focused
- `/recording_studio_exportable/exports` — engine POST endpoint used by the demo CSV export button
- `/docs/install` — install guide rendered inside the dummy app
- `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods` — starter sidebar pages to customize for your gem

The home page in `test/dummy/app/views/home/index.html.erb` is also a deliberate starting point. Keep it focused on a minimal demo of the gem's primary behavior; use the sidebar pages for deeper explanations and supporting reference material.

## Architecture

### Root Recording Pattern

This template follows RecordingStudio's root recording pattern:

- **Workspace** is the top-level recordable
- **Folder** and **Page** demonstrate nested recordables under the workspace root
- Each configured recordable declares `recording_studio_recordable(...)`; strict declaration validation stays enabled
- A root `RecordingStudio::Recording` wraps the Workspace
- `Current.actor` is set from `current_user` (Devise) in `ApplicationController`

### Registering exports

```ruby
RecordingStudioExportable.configure do |config|
  config.register_export(
    "reports.example",
    context_types: ["Workspace"],
    columns: [
      { key: :name, label: "Name", value: ->(row) { row[:name] } },
      { key: :type, label: "Type", value: :type }
    ],
    filename: "example.csv",
    max_rows: 1_000
  ) do |context_recording:, actor:, attributes:, filters:, **|
    [{ name: RecordingStudio.recordable_name(context_recording.recordable), type: context_recording.recordable_type }]
  end
end

RecordingStudio::Exportable::Capabilities::Exportable.enabled(
  on: "Workspace",
  export_keys: ["reports.example"],
  required_role: :view,
  max_rows: 1_000,
  formats: [:csv]
)
```

`RecordingStudioExportable.export(context_recording:, actor:, export_key: "reports.example")` returns result
data, filename, content type, row count, and the created `RecordingStudioExportable::ExportLog`.
Authorization is checked with `RecordingStudioAccessible.authorized?`; rows over the configured limit fail closed.
Only in-memory CSV generation is supported.

### Instance-level allowed export keys

Definitions are global, but each context instance controls which export keys it allows.
By default, `context_export_keys_resolver` reads `recordable.export_keys` or `recordable.export_key`.
An explicit `export_key` must be allowed by that context instance.

### Third-party and host-app overrides

Third-party gems can register exports through `RecordingStudioExportable.configure`.
Host apps can replace definitions safely using `replace: true`:

```ruby
RecordingStudioExportable.configure do |config|
  config.register_export("reports.users", columns: [:email]) { User.limit(10) }
  config.register_export("reports.users", replace: true, columns: [:name, :email]) { User.limit(10) }
end
```

### FlatPack helper

Use `recording_studio_export_button` to render a POST form and FlatPack submit button:

```erb
<%= recording_studio_export_button(
  context_recording: @dashboard_recording,
  export_key: "demo.dashboard_requests",
  attributes: { columns: ["requested_at", "status"] },
  filters: { status: "200" },
  text: "Export CSV",
  style: :primary
) %>
```

### Attributes vs columns

`columns:` are definition-time allowed columns.
`attributes:` in requests represent selected export columns and must be a subset of definition columns.

### Runtime API and configuration

```ruby
RecordingStudioExportable.export(
  context_recording: recording,
  actor: current_user,
  export_key: "reports.example", # optional only when exactly one key is allowed
  attributes: { columns: ["name"] },
  filters: { status: "active" },
  format: :csv,
  filename: "custom.csv",
  controller: self
)
```

Configuration supports `current_actor`, `current_impersonator`, `default_format`, `default_required_role`,
`max_rows`, `include_bom`, `allow_request_filename_override`, `filter_log_sanitizer`, and
`context_export_keys_resolver`.

### Security notes

- Only registered columns can be selected; request attributes cannot expose unapproved data.
- CSV cells and headers beginning with `=`, `+`, `-`, `@`, tab, or carriage return are prefixed with a single quote to reduce spreadsheet formula-injection risk.
- Request filename overrides are ignored unless `allow_request_filename_override` is explicitly enabled, and all filenames are sanitized.
- Export logs store metadata and status only, never CSV contents.

### Explicitly out of scope in v1

- Persistent exported files
- Exporting recordings or recordables as first-class export entities
- Background jobs, scheduled exports, emailed exports
- XLSX/PDF formats (CSV only)
- Admin UI, admin routes/controllers, admin dashboards
- Admin-specific authorization/policy layers

### Extending RecordingStudio

To add new recordable types:

1. Create your model (e.g., `Page`, `Comment`)
2. Register it in `config/initializers/recording_studio.rb`:
   ```ruby
   RecordingStudio.configure do |config|
     config.recordable_types = ["Workspace", "YourNewType"]
   end
   ```
3. Declare whether the model can be a root and which parents may contain it:
   ```ruby
   class YourNewType < ApplicationRecord
     recording_studio_recordable label: "Your new type",
                                 root: false,
                                 allowed_parent_types: ["Workspace", "Folder"]
   end
   ```
4. Validate declarations and create recordings under the root:
   ```ruby
   RecordingStudio.validate_recordable_declarations!
   root_recording = RecordingStudio.root_recording_for(workspace)
   root_recording.record(YourNewType) do |record|
     record.title = "Example"
   end
   ```

### RecordingStudio v3 Declarations

RecordingStudio v3 expects every configured ActiveRecord recordable type to declare its hierarchy rules:

- `Workspace` declares `root: true`
- `Folder` and `Page` declare `root: false, allowed_parent_types: ["Workspace", "Folder"]`
- `config.require_recordable_declarations = true` remains enabled in the dummy app initializer

Useful console checks:

```ruby
RecordingStudio.validate_recordable_declarations!
RecordingStudio.root_recordable_types
RecordingStudio.allowed_parent_types_for("Page")
```

### FlatPack UI Components

All views use FlatPack ViewComponents. Available components include:

- `FlatPack::Button::Component` — Buttons (`:primary`, `:secondary`, `:ghost`)
- `FlatPack::Card::Component` — Cards (`:default`, `:elevated`, `:outlined`)
- `FlatPack::Alert::Component` — Alerts (`:success`, `:error`, `:warning`, `:info`)
- `FlatPack::Badge::Component` — Status badges
- `FlatPack::Table::Component` — Data tables
- `FlatPack::TextInput::Component`, `EmailInput`, `PasswordInput` — Form inputs
- `FlatPack::Breadcrumb::Component` — Navigation breadcrumbs
- `FlatPack::Navbar::Component` — Navigation sidebar

Use the live FlatPack demo app at [flatpack-c6p8f.ondigitalocean.app](https://flatpack-c6p8f.ondigitalocean.app/) as the approved UI reference for current shared patterns. Its component table is the fastest way to discover available FlatPack components before introducing new custom UI, and user-provided FlatPack demo URLs should be treated as task context.

In GitHub Codespaces or other restricted environments, you may need to enable access to that URL before the agent can inspect the app. If access is unavailable, provide sanitized screenshots, copied markup, or component details so the agent can stay aligned with the shared UI.

See the [FlatPack README](https://github.com/bowerbird-app/flatpack) for full documentation.

## Tech Stack

| Component       | Version |
|-----------------|---------|
| Ruby            | 3.3+    |
| Rails           | 8.1+    |
| PostgreSQL      | 16      |
| TailwindCSS     | 4       |
| RecordingStudio | v3.0.0 (pinned to `recording_studio/v3.0.0` in `test/dummy/Gemfile`) |
| FlatPack        | v0.1.95 (pinned in `test/dummy/Gemfile`) |
| Devise          | latest  |

## Documentation

The original gem template documentation is preserved in `docs/recording_studio_exportable/` as architectural reference material. Use it as background on the engine conventions; the README and dummy app are the source of truth for the Recording Studio addon workflow.
