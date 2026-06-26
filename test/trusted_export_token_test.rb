# frozen_string_literal: true

require "test_helper"

class TrustedExportTokenTest < Minitest::Test
  FakeContext = Struct.new(:recordable_type, :recordable)
  FakeRecordable = Struct.new(:id)

  def setup
    @original_configuration = RecordingStudioExportable.instance_variable_get(:@configuration)
    RecordingStudioExportable.instance_variable_set(:@configuration, RecordingStudioExportable::Configuration.new)
    RecordingStudioExportable.configuration.trusted_export_sources = ["RecordingStudioAdmin"]
  end

  def teardown
    RecordingStudioExportable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_issue_and_consume_tracks_audit_metadata
    context = FakeContext.new("DemoDashboard", FakeRecordable.new(1))
    actor = Object.new

    token = issue_token(context_recording: context, actor: actor, screen_identifier: "Admin Users")
    consumed = RecordingStudioExportable::TrustedExportToken.find_and_consume!(token.id)

    assert_same context, consumed.context_recording
    assert_same actor, consumed.actor
    assert_equal "RecordingStudioAdmin", consumed.source
    assert_equal "Admin Users", consumed.screen_identifier
    assert_equal "recordingstudioadmin.admin_users", consumed.effective_export_key
  end

  def test_token_is_single_use
    token = issue_token

    RecordingStudioExportable::TrustedExportToken.find_and_consume!(token.id)

    assert_raises(RecordingStudioExportable::TrustedExportToken::TokenNotFound) do
      RecordingStudioExportable::TrustedExportToken.find_and_consume!(token.id)
    end
  end

  def test_expired_token_raises_token_expired
    token = issue_token(ttl: 0)

    assert_raises(RecordingStudioExportable::TrustedExportToken::TokenExpired) do
      RecordingStudioExportable::TrustedExportToken.find_and_consume!(token.id)
    end

    assert_raises(RecordingStudioExportable::TrustedExportToken::TokenNotFound) do
      RecordingStudioExportable::TrustedExportToken.find_and_consume!(token.id)
    end
  end

  def test_source_allowlist_allows_configured_source
    token = issue_token(source: "RecordingStudioAdmin")

    assert_equal "RecordingStudioAdmin", token.source
  end

  def test_source_allowlist_rejects_unknown_source
    assert_raises(RecordingStudioExportable::TrustedExportToken::Error) do
      issue_token(source: "UnknownGem")
    end
  end

  def test_empty_source_allowlist_rejects_all_sources
    RecordingStudioExportable.configuration.trusted_export_sources = []

    assert_raises(RecordingStudioExportable::TrustedExportToken::Error) do
      issue_token(source: "RecordingStudioAdmin")
    end
  end

  def test_ttl_is_capped_to_default
    token = issue_token(ttl: 1.hour)

    assert_operator token.expires_at, :<=, Time.current + RecordingStudioExportable::TrustedExportToken::DEFAULT_TTL
  end

  def test_id_is_present_and_unique
    first = issue_token
    second = issue_token

    refute_empty first.id
    refute_equal first.id, second.id
  end

  def test_column_normalization_from_hashes
    token = issue_token(columns: [{ key: :name, label: "Name", value: :name }])

    assert_instance_of RecordingStudioExportable::ExportDefinition::Column, token.columns.first
    assert_equal :name, token.columns.first.key
  end

  def test_column_normalization_from_column_objects_preserves_object
    column = column(:name)
    token = issue_token(columns: [column])

    assert_same column, token.columns.first
  end

  def test_store_isolates_multiple_tokens
    first = issue_token(screen_identifier: "first")
    second = issue_token(screen_identifier: "second")

    RecordingStudioExportable::TrustedExportToken.find_and_consume!(first.id)

    assert_equal "second", RecordingStudioExportable::TrustedExportToken.find_and_consume!(second.id).screen_identifier
  end

  def test_default_store_is_process_local_even_when_rails_cache_is_available
    cache = ActiveSupport::Cache::MemoryStore.new

    Rails.stub(:cache, cache) do
      store = RecordingStudioExportable.configuration.resolve_trusted_export_token_store

      assert_instance_of RecordingStudioExportable::TrustedExportTokenStore, store
      refute_same cache, store
    end
  end

  def test_default_store_is_reused
    Rails.stub(:cache, ActiveSupport::Cache::NullStore.new) do
      assert_same RecordingStudioExportable.configuration.resolve_trusted_export_token_store,
                  RecordingStudioExportable.configuration.resolve_trusted_export_token_store
    end
  end

  def test_explicit_token_store_overrides_auto_detection
    store = RecordingStudioExportable::TrustedExportTokenStore.new
    RecordingStudioExportable.configuration.trusted_export_token_store = store

    assert_same store, RecordingStudioExportable.configuration.resolve_trusted_export_token_store
  end

  def test_explicit_token_store_must_support_atomic_consume
    RecordingStudioExportable.configuration.trusted_export_token_store = ActiveSupport::Cache::MemoryStore.new

    assert_raises(RecordingStudioExportable::TrustedExportToken::Error) do
      issue_token
    end
  end

  def test_issue_requires_actor
    assert_raises(RecordingStudioExportable::TrustedExportToken::Error) do
      issue_token(actor: nil)
    end
  end

  def test_concurrent_consume_allows_one_success
    token = issue_token
    successes = Queue.new
    failures = Queue.new

    threads = 2.times.map do
      Thread.new do
        RecordingStudioExportable::TrustedExportToken.find_and_consume!(token.id)
        successes << true
      rescue RecordingStudioExportable::TrustedExportToken::TokenNotFound
        failures << true
      end
    end
    threads.each(&:join)

    assert_equal 1, successes.size
    assert_equal 1, failures.size
  end

  def test_find_and_consume_uses_store_atomic_consume
    store = RecordingStudioExportable::TrustedExportTokenStore.new
    RecordingStudioExportable.configuration.trusted_export_token_store = store
    token = issue_token
    calls = 0

    store.define_singleton_method(:read) do |_key|
      raise "find_and_consume! must not perform non-atomic read/delete"
    end
    store.define_singleton_method(:delete) do |_key|
      raise "find_and_consume! must not perform non-atomic read/delete"
    end
    original_consume = store.method(:consume)
    store.define_singleton_method(:consume) do |key|
      calls += 1
      original_consume.call(key)
    end

    assert_same token, RecordingStudioExportable::TrustedExportToken.find_and_consume!(token.id)
    assert_equal 1, calls
  end

  private

  def issue_token(source: "RecordingStudioAdmin", screen_identifier: "admin.users",
                  context_recording: FakeContext.new("DemoDashboard", FakeRecordable.new(1)),
                  actor: Object.new, columns: [column(:name)], row_resolver: -> { [] },
                  ttl: RecordingStudioExportable::TrustedExportToken::DEFAULT_TTL)
    RecordingStudioExportable.issue_trusted_token(
      context_recording: context_recording,
      actor: actor,
      source: source,
      screen_identifier: screen_identifier,
      columns: columns,
      row_resolver: row_resolver,
      ttl: ttl
    )
  end

  def column(key)
    RecordingStudioExportable::ExportDefinition::Column.new(key: key, label: key.to_s.titleize, value: key)
  end
end
