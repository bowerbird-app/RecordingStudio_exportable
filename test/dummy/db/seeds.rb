# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable,
    trashed_at: nil
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

ensure_access_role = lambda do |recording:, actor:, role:, manager_actor:|
  grant_result = RecordingStudioAccessible.grant_access(
    recording: recording,
    actor: actor,
    role: role,
    manager_actor: manager_actor
  )
  raise grant_result.error if grant_result.failure?

  access_recording = RecordingStudio::Recording
    .joins("INNER JOIN recording_studio_accesses ON recording_studio_accesses.id = recording_studio_recordings.recordable_id")
    .where(
      trashed_at: nil,
      parent_recording_id: recording.id,
      recordable_type: "RecordingStudio::Access",
      "recording_studio_accesses.actor_type" => actor.class.name,
      "recording_studio_accesses.actor_id" => actor.id
    )
    .order(created_at: :desc, id: :desc)
    .first

  access_recordable = access_recording&.recordable
  return unless access_recordable&.respond_to?(:role) && access_recordable.role.to_s != role.to_s

  access_recordable.update!(role: role)
end

find_access_recording_for = lambda do |recording:, actor:|
  RecordingStudio::Recording
    .joins("INNER JOIN recording_studio_accesses ON recording_studio_accesses.id = recording_studio_recordings.recordable_id")
    .where(
      trashed_at: nil,
      parent_recording_id: recording.id,
      recordable_type: "RecordingStudio::Access",
      "recording_studio_accesses.actor_type" => actor.class.name,
      "recording_studio_accesses.actor_id" => actor.id
    )
    .order(created_at: :desc, id: :desc)
    .first
end

clear_access_for = lambda do |recording:, actor:|
  access_recording = find_access_recording_for.call(recording: recording, actor: actor)
  access_recording&.update!(trashed_at: Time.current)
end

# Create the demo users
user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

viewer_user = User.find_or_create_by!(email: "viewer@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

# Create the workspace recordables
workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
accessible_workspace = Workspace.find_or_create_by!(name: "Client Workspace")
private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Getting Started")
demo_dashboard = DemoDashboard.find_or_create_by!(name: "Export Demo Dashboard")
document = Document.find_or_create_by!(title: "Export Governance Handbook")

document_items = [
  [ "Owner", "Document ownership and escalation contact." ],
  [ "Retention", "How long exports are retained and archived." ],
  [ "Encryption", "At-rest and in-transit requirements for exported data." ],
  [ "Redaction", "Fields that must be filtered before CSV generation." ],
  [ "Auditing", "Event trail requirements for export actions." ],
  [ "Incident SOP", "Steps to follow when an export contains sensitive data." ],
  [ "Vendor Review", "Checklist for third-party transfer approvals." ],
  [ "Rotation", "Credential rotation cadence for export integrations." ]
]

document.items.where.not(name: document_items.map(&:first)).delete_all
document_items.each do |name, description|
  Item.find_or_create_by!(document: document, name: name) do |item|
    item.description = description
  end
  Item.where(document: document, name: name).update_all(description: description, updated_at: Time.current)
end

authors = [
  [ "Ava Editor", "Leads the editorial voice for export documentation and examples." ],
  [ "Noah Analyst", "Focuses on analytics exports and practical reporting workflows." ]
].map do |name, bio|
  Author.find_or_create_by!(name: name) { |record| record.bio = bio }
end

article_data = [
  [
    "Recording Studio Export Walkthrough",
    "Recording Studio exports can be attached directly to recordable models and streamed as sanitized CSV files.",
    "Ava Editor",
    [ "Exports", "CSV", "Security" ]
  ],
  [
    "Access Control and Export Roles",
    "Role-aware exports should match the effective access policy from RecordingStudioAccessible.",
    "Noah Analyst",
    [ "Authorization", "Roles", "Policies" ]
  ]
]

shared_topic_bases = [
  "Incident response",
  "Audit log",
  "Policy templates",
  "Role mapping",
  "Least privilege",
  "SOC2 controls",
  "Workflow approvals",
  "CSV validation",
  "Data residency",
  "Release checklist"
]
shared_topics = shared_topic_bases.each_with_index.map { |name, index| "#{name} #{index + 1}" }
article_data = article_data.map do |title, body, author_name, base_topics|
  unique_topic_words = if title.include?("Walkthrough")
    [ "Onboarding", "Pipelines", "Payload", "Schema", "Retries", "Backfill", "Snapshots", "Diffs" ]
  else
    [ "Ownership", "Permissions", "Escalation", "Boundaries", "Delegation", "Approvals", "Review", "Signoff" ]
  end
  unique_topics = (1..37).map do |index|
    stem = unique_topic_words[(index - 1) % unique_topic_words.length]
    "#{stem} Pattern #{index}"
  end
  [ title, body, author_name, (base_topics + shared_topics + unique_topics) ]
end

articles = article_data.map do |title, body, author_name, topic_names|
  author = authors.detect { |candidate| candidate.name == author_name }
  article = Article.find_by(title: title)
  article ||= Article.create!(title: title, body: body, author: author)

  # Keep seed data deterministic even when existing rows were backfilled by migrations.
  Article.where(id: article.id).update_all(author_id: author.id, body: body, updated_at: Time.current)
  article.reload

  article.topics.where.not(name: topic_names).delete_all

  topic_names.each do |topic_name|
    Topic.find_or_create_by!(article: article, name: topic_name)
  end

  article
end

[
  [ "/api/pages", "GET", 200, 42 ],
  [ "/api/folders", "GET", 200, 31 ],
  [ "/api/recordings", "POST", 201, 87 ],
  [ "/api/exports", "GET", 200, 53 ],
  [ "/api/exports", "POST", 202, 96 ],
  [ "/api/articles", "GET", 200, 38 ]
].each do |path, http_method, status, duration_ms|
  demo_dashboard.demo_api_requests.find_or_create_by!(path: path, http_method: http_method) do |request|
    request.status = status
    request.duration_ms = duration_ms
  end
end

previous_actor = Current.actor
Current.actor = user

begin
  # Create the root recording
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)
  demo_dashboard_recording = RecordingStudio.root_recording_for(demo_dashboard)
  document_recording = RecordingStudio.root_recording_for(document)
  article_recordings = articles.index_with { |article| RecordingStudio.root_recording_for(article) }
  ensure_access_role.call(recording: demo_dashboard_recording, actor: user, role: :admin, manager_actor: user)
  ensure_access_role.call(recording: demo_dashboard_recording, actor: viewer_user, role: :view, manager_actor: user)
  ensure_access_role.call(recording: document_recording, actor: user, role: :admin, manager_actor: user)
  clear_access_for.call(recording: document_recording, actor: viewer_user)

  article_recordings.each_value do |article_recording|
    ensure_access_role.call(recording: article_recording, actor: user, role: :admin, manager_actor: user)
    ensure_access_role.call(recording: article_recording, actor: viewer_user, role: :view, manager_actor: user)
  end

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)

  find_or_record_child.call(page, root_recording, folder_recording)
  demo_dashboard.demo_api_requests.find_each do |request|
    find_or_record_child.call(request, demo_dashboard_recording, demo_dashboard_recording)
  end
  document.items.find_each do |item|
    find_or_record_child.call(item, document_recording, document_recording)
  end
  articles.each do |article|
    article_recording = article_recordings.fetch(article)
    find_or_record_child.call(article.author, article_recording, article_recording)
    article.topics.find_each do |topic|
      find_or_record_child.call(topic, article_recording, article_recording)
    end
  end
ensure
  Current.actor = previous_actor
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: viewer@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
puts "Seeded: Demo dashboard '#{demo_dashboard.name}' with exportable API request rows"
puts "Seeded: Document '#{document.title}' with #{document.items.count} items"
puts "Seeded: #{articles.count} articles with authors and topics"
