# frozen_string_literal: true

require "securerandom"
require "active_support/core_ext/numeric/time"
require "active_support/core_ext/object/blank"

module RecordingStudioExportable
  class TrustedExportToken
    class Error < RecordingStudioExportable::Error; end
    class TokenNotFound < Error; end
    class TokenExpired < Error; end

    DEFAULT_TTL = 5.minutes

    attr_reader :id, :context_recording, :actor, :columns, :row_resolver,
                :source, :screen_identifier, :effective_export_key, :expires_at

    def initialize(id:, context_recording:, actor:, columns:, row_resolver:,
                   source:, screen_identifier:, effective_export_key:, expires_at:)
      @id = id
      @context_recording = context_recording
      @actor = actor
      @columns = columns
      @row_resolver = row_resolver
      @source = source.to_s
      @screen_identifier = screen_identifier.to_s
      @effective_export_key = effective_export_key
      @expires_at = expires_at
    end

    def self.issue(context_recording:, actor:, source:, screen_identifier:,
                   columns:, row_resolver:, ttl: DEFAULT_TTL)
      raise Error, "context_recording is required" unless context_recording
      raise Error, "actor is required" unless actor
      raise Error, "row_resolver is required" unless row_resolver.respond_to?(:call)
      raise Error, "columns are required" if columns.blank?
      raise Error, "source is required" if source.blank?
      raise Error, "screen_identifier is required" if screen_identifier.blank?

      allowed = RecordingStudioExportable.configuration.trusted_export_sources
      raise Error, "source #{source.inspect} is not allowed" unless Array(allowed).map(&:to_s).include?(source.to_s)

      ttl_seconds = [ttl.to_i, DEFAULT_TTL.to_i].min
      id = SecureRandom.urlsafe_base64(32)
      normalized_columns = columns.map { |column| normalize_column(column) }
      effective_key = [
        RecordingStudioExportable.configuration.normalize_key(source),
        RecordingStudioExportable.configuration.normalize_key(screen_identifier)
      ].join(".")

      token = new(
        id: id,
        context_recording: context_recording,
        actor: actor,
        source: source,
        screen_identifier: screen_identifier,
        columns: normalized_columns,
        row_resolver: row_resolver,
        effective_export_key: effective_key,
        expires_at: Time.current + ttl_seconds
      )

      store.write(token.id, token, expires_in: ttl_seconds.positive? ? ttl_seconds : nil)
      token
    end

    def self.find_and_consume!(id)
      token = token_store.consume(id)
      raise TokenNotFound, "export token not found or expired" unless token
      raise TokenExpired, "export token has expired" if token.expires_at < Time.current

      token
    end

    def self.store
      token_store
    end

    def self.token_store
      store = RecordingStudioExportable.configuration.resolve_trusted_export_token_store
      unless store.respond_to?(:write) && store.respond_to?(:consume)
        raise Error, "trusted_export_token_store must implement write and atomic consume"
      end

      store
    end

    def self.normalize_column(column)
      if column.is_a?(ExportDefinition::Column)
        column
      elsif column.is_a?(Hash)
        ExportDefinition::Column.new(column.transform_keys(&:to_sym))
      elsif column.respond_to?(:to_h)
        ExportDefinition::Column.new(column.to_h.transform_keys(&:to_sym))
      else
        raise ArgumentError, "column must be ExportDefinition::Column or Hash, got #{column.class}"
      end
    end
  end
end
