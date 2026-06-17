class Article < ApplicationRecord
  recording_studio_recordable label: "Article", root: true
  belongs_to :author
  has_many :topics, dependent: :destroy

  RecordingStudio::Exportable::Capabilities::Exportable.enabled(
    export_keys: ["recording_studio_article_export", "recording_studio_article_topics_authors_export"]
  )

  def export_keys
    [ "recording_studio_article_export", "recording_studio_article_topics_authors_export" ]
  end
end