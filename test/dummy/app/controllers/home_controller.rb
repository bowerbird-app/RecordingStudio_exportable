class HomeController < ApplicationController
  ARTICLE_TOPICS_PER_PAGE = 20
  TOPICS_PER_PAGE = 20
  TOPICS_TABLE_COLUMNS = ["topic_name", "article_titles", "topic_created_at"].freeze
  DEFAULT_TOPICS_TABLE_COLUMNS = TOPICS_TABLE_COLUMNS.freeze

  def index
    @demo_dashboard = DemoDashboard.includes(:demo_api_requests).order(:name).first
    @demo_recording = RecordingStudio.root_recording_for(@demo_dashboard) if @demo_dashboard
    @current_actor_email = Current.actor&.respond_to?(:email) ? Current.actor.email : nil
    @dashboard_view_allowed = @demo_recording.present? && Current.actor.present? &&
      RecordingStudioAccessible.authorized?(actor: Current.actor, recording: @demo_recording, role: :view)
    @dashboard_admin_allowed = @demo_recording.present? && Current.actor.present? &&
      RecordingStudioAccessible.authorized?(actor: Current.actor, recording: @demo_recording, role: :admin)
    @dashboard_allowed_export_keys = if @demo_recording.present? && Current.actor.present?
      RecordingStudioExportable.configuration.export_keys_for(recording: @demo_recording, actor: Current.actor)
    else
      []
    end
    @article_export_allowed = @dashboard_allowed_export_keys.include?("recording_studio_article_export")
    @documents = Document.order(:title).limit(10)

    articles = Article.includes(:author, :topics).order(:title).to_a
    @article_rows = articles.map do |article|
      {
        article: article,
        title: article.title,
        author_name: article.author&.name,
        topics: article.topics.order(:name).map(&:name),
        topic_count: article.topics.size,
        word_count: article.body.to_s.split.size,
        context_recording: RecordingStudio.root_recording_for(article)
      }
    end

    @article_topic_rows = @article_rows.flat_map do |row|
      article = row.fetch(:article)
      article.topics.order(:name).map do |topic|
        {
          article_title: article.title,
          topic_name: topic.name,
          author_name: article.author&.name,
          context_recording: row.fetch(:context_recording)
        }
      end
    end

    @article_topics_total_rows = @article_topic_rows.length
    @article_topics_page = params[:article_topics_page].to_i
    @article_topics_page = 1 if @article_topics_page < 1
    @article_topics_total_pages = [(@article_topics_total_rows.to_f / ARTICLE_TOPICS_PER_PAGE).ceil, 1].max
    @article_topics_page = @article_topics_total_pages if @article_topics_page > @article_topics_total_pages

    article_topics_offset = (@article_topics_page - 1) * ARTICLE_TOPICS_PER_PAGE
    @article_topic_rows_page = @article_topic_rows.slice(article_topics_offset, ARTICLE_TOPICS_PER_PAGE) || []

    @topic_filter = params[:topic].to_s.strip
    @article_filter = params[:article].to_s.strip
    @topics_created_at_start = normalize_topics_created_at(params[:topics_created_at_start])
    @topics_created_at_end = normalize_topics_created_at(params[:topics_created_at_end])
    @topics_selected_columns = normalize_topics_columns(params[:topics_columns])
    @topics_column_options = [
      { key: "topic_name", title: "Topic" },
      { key: "article_titles", title: "Articles" },
      { key: "topic_created_at", title: "Created at" }
    ]

    topic_scope = Topic.includes(article: :author).order(:name)
    topic_scope = topic_scope.where("topics.name ILIKE ?", "%#{@topic_filter}%") if @topic_filter.present?
    topic_scope = topic_scope.joins(:article).where("articles.title ILIKE ?", "%#{@article_filter}%") if @article_filter.present?
    topic_scope = topic_scope.where("topics.created_at >= ?", @topics_created_at_start.beginning_of_day) if @topics_created_at_start
    topic_scope = topic_scope.where("topics.created_at <= ?", @topics_created_at_end.end_of_day) if @topics_created_at_end

    grouped_topic_rows = topic_scope.group_by(&:name).map do |topic_name, topics|
      {
        topic_name: topic_name,
        article_titles: topics.filter_map { |topic| topic.article&.title_with_author }.uniq.sort.join(", "),
        topic_created_at: topics.filter_map(&:formatted_created_at).uniq.sort.join(", ")
      }
    end
    @topic_article_rows = grouped_topic_rows.sort_by { |row| row[:topic_name].to_s.downcase }

    @topics_total_rows = @topic_article_rows.length
    @topics_page = params[:topics_page].to_i
    @topics_page = 1 if @topics_page < 1
    @topics_total_pages = [(@topics_total_rows.to_f / TOPICS_PER_PAGE).ceil, 1].max
    @topics_page = @topics_total_pages if @topics_page > @topics_total_pages

    topics_offset = (@topics_page - 1) * TOPICS_PER_PAGE
    @topic_article_rows_page = @topic_article_rows.slice(topics_offset, TOPICS_PER_PAGE) || []

    # --- Token-based export demo ---
    @trusted_token = nil
    if @demo_recording.present? && Current.actor.present?
      begin
        @trusted_token = issue_demo_token(@demo_recording)
      rescue StandardError
        @trusted_token = nil
      end
    end
  end

  private

  def normalize_topics_columns(raw_columns)
    normalized = Array(raw_columns).map(&:to_s).map(&:strip).reject(&:blank?).uniq
    selected = normalized & TOPICS_TABLE_COLUMNS
    selected.presence || DEFAULT_TOPICS_TABLE_COLUMNS
  end

  def normalize_topics_created_at(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def issue_demo_token(recording)
    RecordingStudioExportable.issue_trusted_token(
      context_recording: recording,
      actor: Current.actor,
      source: "RecordingStudioAdmin",
      screen_identifier: "Homepage Demo Export",
      columns: [
        { key: :title, label: "Title", value: :title },
        { key: :body, label: "Body", value: :body },
        { key: :word_count, label: "Word count", value: ->(article) { article.body.to_s.split.size } }
      ],
      row_resolver: -> { Article.order(:title).to_a },
      ttl: 30.seconds
    )
  end
end
