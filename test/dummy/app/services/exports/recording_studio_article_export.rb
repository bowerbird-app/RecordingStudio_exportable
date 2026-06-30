class RecordingStudioArticleExport
  KEY = "recording_studio_article_export".freeze

  DASHBOARD_CONTEXT_TYPES = [ "Article", "DemoDashboard" ].freeze

  def self.register(config)
    config.register_export(
      KEY,
      label: "Article content",
      description: "Exports article records from the dummy app.",
      required_role: :admin,
      context_types: DASHBOARD_CONTEXT_TYPES,
      columns: [
        { key: :title, label: "Title", value: :title },
        { key: :body, label: "Body", value: :body },
        { key: :word_count, label: "Word count", value: ->(article) { word_count(article) } }
      ],
      allowed_attributes: {
        articles: [
          { key: :title, label: "Title", value: :title },
          { key: :body, label: "Body", value: :body },
          { key: :word_count, label: "Word count", value: ->(article) { word_count(article) } }
        ]
      },
      filename: method(:filename)
    ) do |context_recording:, **|
      records_for(context_recording)
    end
  end

  def self.filename(context_recording:, **)
    recordable = context_recording.recordable

    return "articles.csv" if recordable.is_a?(DemoDashboard)

    "#{recordable.title.parameterize.presence || 'article'}.csv"
  end

  def self.records_for(context_recording)
    recordable = context_recording.recordable

    return Article.order(:title).to_a if recordable.is_a?(DemoDashboard)

    [ recordable ]
  end

  def self.word_count(article)
    article.body.to_s.split.size
  end
end
