class DemoDashboard < ApplicationRecord
  recording_studio_recordable label: "Demo Dashboard", root: true

  has_many :demo_api_requests, dependent: :destroy
end
