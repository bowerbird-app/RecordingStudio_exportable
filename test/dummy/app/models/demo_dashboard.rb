class DemoDashboard < ApplicationRecord
  EXPORT_KEYS = [
    "recording_studio_demo_dashboard_requests_export",
    "recording_studio_article_export",
    "recording_studio_article_topics_authors_export",
    "recording_studio_topics_articles_export"
  ].freeze

  recording_studio_recordable label: "Demo Dashboard", root: true
  RecordingStudio::Exportable::Capabilities::Exportable.enabled(
    export_keys: EXPORT_KEYS
  )

  has_many :demo_api_requests, dependent: :destroy
end
