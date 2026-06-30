class Article < ApplicationRecord
  recording_studio_recordable label: "Article", root: true
  belongs_to :author
  has_many :topics, dependent: :destroy

  def title_with_author
    author_label = author&.name.presence || "Unknown author"
    "#{title} - #{author_label}"
  end

  RecordingStudio::Exportable::Capabilities::Exportable.enabled(
    export_keys: [
      "recording_studio_article_export",
      "recording_studio_article_topics_authors_export"
    ]
  )
end
