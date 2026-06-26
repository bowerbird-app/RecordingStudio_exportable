class RecordingStudioTopicsArticlesExport
  KEY = "recording_studio_topics_articles_export".freeze

  def self.register(config)
    config.register_export(
      KEY,
      label: "Topics with articles",
      description: "Exports topic names and matching article titles with author names.",
      required_role: :admin,
      context_types: [ "DemoDashboard" ],
      columns: [
        { key: :topic_name, label: "Topic", value: ->(row) { row[:topic_name] } },
        { key: :article_titles, label: "Articles", value: ->(row) { row[:article_titles] } }
      ],
      allowed_attributes: {
        topics: [
          { key: :name, label: "Topic", value: :name }
        ],
        articles: [
          { key: :title, label: "Article", value: :title },
          { key: :title_with_author, label: "Article with author", value: :title_with_author }
        ]
      },
      filename: "topics-articles.csv"
    ) do |context_recording:, filters:, **|
      rows_for(context_recording: context_recording, filters: filters)
    end
  end

  def self.rows_for(context_recording:, filters:)
    filter_topic = extract_filter(filters, :topic)
    filter_article = extract_filter(filters, :article)

    scope = Topic.includes(article: :author).order(:name)
    scope = scope.where("topics.name ILIKE ?", "%#{filter_topic}%") if filter_topic.present?
    scope = scope.joins(:article).where("articles.title ILIKE ?", "%#{filter_article}%") if filter_article.present?

    scope.group_by(&:name).map do |topic_name, topics|
      {
        topic_name: topic_name,
        article_titles: topics.filter_map { |topic| topic.article&.title_with_author }.uniq.sort.join(", ")
      }
    end.sort_by { |row| row[:topic_name].to_s.downcase }
  end

  def self.extract_filter(filters, key)
    return if filters.blank?

    value = filters[key] || filters[key.to_s]
    value.to_s.strip.presence
  end
end
