# RecordingStudioExportable API Cheat Sheet

This note explains the two main APIs used in the dummy app configuration:

- `config.register_export(...)`
- `RecordingStudio::Exportable::Capabilities::Exportable.enabled(...)`

It also explains how `context_recording`, `context_types`, and `required_role` fit into the access model.

In the current convention, export definitions live in `app/services/exports/**/*_export.rb` and the initializer calls `RecordingStudioExportable.auto_register_exports!(config)`.

## 1. `config.register_export(...)`

This defines one export.

Think of it as:

- the export key that exists in the system
- the metadata for that export
- the resolver block that returns the rows

Example export class:

```ruby
class RecordingStudioDemoDashboardRequestsExport
  def self.register(config)
    config.register_export(
      "recording_studio_demo_dashboard_requests_export",
      label: "Demo API requests",
      description: "Exports the API request rows shown on the demo dashboard.",
      context_types: ["DemoDashboard"],
      columns: [
        { key: :path, label: "Path", value: :path },
        { key: :method, label: "Method", value: :http_method },
        { key: :status, label: "Status", value: :status },
        { key: :duration_ms, label: "Duration (ms)", value: :duration_ms }
      ],
      filename: ->(context_recording:, **) { "#{context_recording.recordable.name}-api-requests.csv" }
    ) do |context_recording:, filters:, **|
      scope = context_recording.recordable.demo_api_requests.order(:created_at)
      scope = scope.where(status: filters[:status]) if filters[:status].present?
      scope
    end
  end
end
```

Example initializer:

```ruby
RecordingStudioExportable.configure do |config|
  config.current_actor = ->(controller: nil) { controller&.send(:current_user) || Current.actor }
  RecordingStudioExportable.auto_register_exports!(config)
end
```

### What can be passed to `register_export`

The method shape is:

```ruby
register_export(key, replace: false, **options, &block)
```

#### Required

- `key` - the unique export key

#### Optional

- `replace:` - when `true`, replace an existing definition with the same key
- `label:` - human-friendly name
- `description:` - human-friendly description
- `context_types:` - allowed context recordable types
- `context_key:` or `context_keys:` - optional extra screen/section restriction inside the context
- `columns:` - all allowed columns for the export
- `default_columns:` - columns used when none are requested
- `filename:` - static string or callable that returns a filename
- `required_role:` - role checked through RecordingStudio Accessible
- `max_rows:` - row limit for the export
- `formats:` - allowed output formats
- `resolver:` - explicit resolver callable
- `context_predicate:` - optional custom context check

#### Block parameters

The export block can receive:

- `context_recording:`
- `actor:`
- `attributes:`
- `filters:`
- `format:`
- `controller:`

High-level meaning:

- `context_recording:` - the current RecordingStudio context the export runs from
- `actor:` - the current user/actor running the export
- `attributes:` - requested export attributes (for example selected columns)
- `filters:` - filter values from the request (for example status/date filters)
- `format:` - requested output format (v1 is CSV)
- `controller:` - current controller instance when available

Example:

```ruby
do |context_recording:, actor:, attributes:, filters:, format:, controller:|
  # return rows here
end
```

Example with real usage:

```ruby
config.register_export(
  "recording_studio_demo_dashboard_requests_export",
  context_types: ["DemoDashboard"],
  columns: [
    { key: :path, label: "Path", value: :path },
    { key: :status, label: "Status", value: :status }
  ]
) do |context_recording:, actor:, attributes:, filters:, format:, controller:|
  # 1) Start from the current export context
  scope = context_recording.recordable.demo_api_requests.order(:created_at)

  # 2) Apply incoming filters
  scope = scope.where(status: filters[:status]) if filters[:status].present?

  # 3) Optional actor-aware filtering
  scope = scope.where(private: false) unless actor&.respond_to?(:admin?) && actor.admin?

  # 4) You can inspect attributes/format/controller if needed
  requested = attributes.is_a?(Hash) ? attributes[:columns] || attributes["columns"] : attributes
  Rails.logger.debug("export columns=#{requested.inspect} format=#{format} controller=#{controller.class.name if controller}")

  scope
end
```

### What `register_export` means in practice

This is the definition of a single export.

- It says the export key exists.
- It says which context types may use it.
- It says which columns are allowed.
- It says how to build the rows.

If you need two exports, you call `register_export` twice with two different keys.

## 2. `RecordingStudio::Exportable::Capabilities::Exportable.enabled(...)`

This enables export keys for a recordable type.

Think of it as:

- the allowlist for a recordable type
- the second lock after the export is defined globally

Example:

```ruby
class DemoDashboard < ApplicationRecord
  recording_studio_recordable label: "Demo Dashboard", root: true

  RecordingStudio::Exportable::Capabilities::Exportable.enabled(
    export_keys: ["recording_studio_demo_dashboard_requests_export"]
  )
end
```

### What can be passed to `enabled`

The capability method is used like this:

```ruby
enabled(export_keys: [...], **options)
```

#### Required

- call `enabled(...)` from inside the recordable model class body so the recordable type can be inferred

#### Optional

- `export_keys:` - array of export keys allowed for that type
- `exports:` - alias for `export_keys`
- `required_role:` - role default for that type
- `max_rows:` - row limit default for that type
- `formats:` - allowed formats default for that type

### What this means

This does not define the export itself.

It only says which export keys are allowed on that context type.

If you want the same export on another context type, you need another `enabled(...)` call for that other type.

Example:

```ruby
class DemoDashboard < ApplicationRecord
  RecordingStudio::Exportable::Capabilities::Exportable.enabled(
    export_keys: ["recording_studio_demo_dashboard_requests_export"]
  )
end

class Workspace < ApplicationRecord
  RecordingStudio::Exportable::Capabilities::Exportable.enabled(
    export_keys: ["recording_studio_demo_dashboard_requests_export"]
  )
end
```

## 3. The two-lock model

An export must pass two gates:

1. It must be registered globally.
2. It must be allowed on the specific context type/instance.

That means:

- `register_export(...)` creates the export definition
- `enabled(...)` allows that definition on a particular recordable type

If either one is missing, the export should fail.

## 4. `context_recording`

`context_recording` is the export context object.

It is the anchor for:

- access control
- allowed export key lookup
- export log association
- RecordingStudio event logging

In simple terms, it tells the system:

> "Run this export from this exact screen/context."

### Why it is needed

The rows you export can come from any place:

- unrelated models
- joins
- SQL queries
- reports
- dashboards
- POROs
- arrays

But the permission check still happens against the context recording.

That means the system checks:

1. Is this export key allowed for this context?
2. Is the actor authorized for this context?
3. Is this definition valid for this context type?

## 5. `context_types`

`context_types` is the list of allowed recordable types for the export definition.

It is an array because one export can be valid for one type or for many types.

Examples:

```ruby
context_types: ["DemoDashboard"]
```

Only `DemoDashboard` can use it.

```ruby
context_types: ["Page", "Workspace", "AdminScreen"]
```

Any of those context types can use it.

### Important

`context_types` is about the allowed context, not the tables queried by the export.

You can query many tables in the resolver and still keep `context_types: ["DemoDashboard"]`.

## 6. `context_key` and `context_keys`

`context_key` and `context_keys` are optional extra restrictions for where an export can be used inside a context type.

Think of them as a narrower filter than `context_types`.

Examples:

```ruby
context_key: "requests_table"
```

```ruby
context_keys: ["requests_table", "overview_panel"]
```

### What they mean

- `context_key` = one specific screen/section key
- `context_keys` = multiple allowed screen/section keys

If you do not set either one, there is no extra screen/section restriction.

## 7. `required_role`

`required_role` is the role passed into RecordingStudio Accessible.

The access check is effectively:

```ruby
RecordingStudioAccessible.authorized?(
  actor: actor,
  recording: context_recording,
  role: required_role
)
```

### Role resolution order

The brief resolves the role in this order:

1. definition-level `required_role`
2. capability-level `required_role`
3. config default `default_required_role`
4. fallback `:view`

### Simple example

```ruby
config.register_export(
  "pages.with_articles",
  required_role: :admin
) do |context_recording:, **|
  # resolver
end
```

This means that specific export needs admin access unless something more specific is set elsewhere.

## 8. Why resolver scoping still matters

Passing the access check does not automatically make every joined row safe.

Example risk:

1. User can export from `Workspace A`.
2. Export is allowed on `Workspace A`.
3. Resolver joins `articles` without filtering by workspace.
4. Export can accidentally include rows from another workspace.

So the resolver should still be scoped carefully:

- anchor the query to the context
- apply visibility filters or policy scopes
- then return rows

## 9. Short version

- `register_export(...)` = define the export
- `enabled(...)` = allow that export key on a context type
- `context_recording` = the export boundary and permission anchor
- `context_types` = allowed context types, not table names
- `context_key` / `context_keys` = extra optional screen/section restriction inside the context
- `required_role` = the role checked through Accessible
- resolver query = still needs safe scoping for joined/unrelated tables
