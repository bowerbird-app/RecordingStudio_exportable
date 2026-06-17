class DemoDashboard < ApplicationRecord
  recording_studio_recordable label: "Demo Dashboard", root: true
  RecordingStudio::Exportable::Capabilities::Exportable.enabled(
    export_keys: ["recording_studio_demo_dashboard_requests_export"]
  )

  def export_keys
    [ "recording_studio_demo_dashboard_requests_export" ]
  end

  has_many :demo_api_requests, dependent: :destroy
end
