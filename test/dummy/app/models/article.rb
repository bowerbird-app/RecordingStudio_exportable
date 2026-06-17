class Article < ApplicationRecord
  EXPORT_KEYS = [
    "recording_studio_article_export",
    "recording_studio_article_topics_authors_export"
  ].freeze

  recording_studio_recordable label: "Article", root: true
  belongs_to :author
  has_many :topics, dependent: :destroy

  RecordingStudio::Exportable::Capabilities::Exportable.enabled(
    export_keys: EXPORT_KEYS
  )
end