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

# Create the admin user
user = User.find_or_create_by!(email: "admin@admin.com") do |u|
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

[
  ["/api/pages", "GET", 200, 42],
  ["/api/folders", "GET", 200, 31],
  ["/api/recordings", "POST", 201, 87]
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
  grant_result = RecordingStudioAccessible.grant_access(
    recording: demo_dashboard_recording,
    actor: user,
    role: :admin,
    manager_actor: user
  )
  raise grant_result.error if grant_result.failure?

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)

  find_or_record_child.call(page, root_recording, folder_recording)
  demo_dashboard.demo_api_requests.find_each do |request|
    find_or_record_child.call(request, demo_dashboard_recording, demo_dashboard_recording)
  end
ensure
  Current.actor = previous_actor
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
puts "Seeded: Demo dashboard '#{demo_dashboard.name}' with exportable API request rows"
