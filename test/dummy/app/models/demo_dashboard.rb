class DemoDashboard < ApplicationRecord
  recording_studio_recordable label: "Demo Dashboard", root: true
  def export_keys
    [ "demo.dashboard_requests" ]
  end

  has_many :demo_api_requests, dependent: :destroy
end
