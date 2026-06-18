class RecordingStudioArticleTopicsAuthorsExport
  KEY = "recording_studio_article_topics_authors_export".freeze

  DASHBOARD_CONTEXT_TYPES = ["Article", "DemoDashboard"].freeze

  def self.register(config)
    config.register_export(
      KEY,
      label: "Article topics with author",
      description: "Exports article topics with associated author metadata.",
      required_role: :view,
      context_types: DASHBOARD_CONTEXT_TYPES,
      columns: [
        { key: :article_title, label: "Article", value: ->(row) { row[:article_title] } },
        { key: :author_name, label: "Author", value: ->(row) { row[:author_name] } },
        { key: :topic_name, label: "Topic", value: ->(row) { row[:topic_name] } }
      ],
      allowed_attributes: {
        articles: [
          { key: :title, label: "Article", value: :title }
        ],
        authors: [
          { key: :name, label: "Author", value: :name }
        ],
        topics: [
          { key: :name, label: "Topic", value: :name }
        ]
      },
      filename: method(:filename)
    ) do |context_recording:, **|
      rows_for(context_recording)
    end
  end

  def self.filename(context_recording:, **)
    recordable = context_recording.recordable
    return "articles-topics-authors.csv" if recordable.is_a?(DemoDashboard)

    base = recordable.title.parameterize.presence || "article"
    "#{base}-topics-authors.csv"
  end

  def self.rows_for(context_recording)
    records_for(context_recording).flat_map do |article|
      article.topics.order(:name).map do |topic|
        {
          article_title: article.title,
          author_name: article.author&.name,
          topic_name: topic.name
        }
      end
    end
  end

  def self.records_for(context_recording)
    recordable = context_recording.recordable

    return Article.includes(:author, :topics).order(:title).to_a if recordable.is_a?(DemoDashboard)

    [recordable]
  end
end