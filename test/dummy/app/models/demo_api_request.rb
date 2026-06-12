class DemoApiRequest < ApplicationRecord
  recording_studio_recordable label: "Demo API Request", root: false, allowed_parent_types: [ "DemoDashboard" ]

  belongs_to :demo_dashboard
end
