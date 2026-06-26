# frozen_string_literal: true

module RecordingStudioExportable
  class TrustedExportTokenStore
    def initialize
      @store = {}
      @expiries = {}
      @mutex = Mutex.new
    end

    def write(key, value, expires_in: nil)
      @mutex.synchronize do
        @store[key] = value
        @expiries[key] = Time.current + expires_in if expires_in
      end
    end

    def read(key)
      @mutex.synchronize do
        read_unlocked(key)
      end
    end

    def consume(key)
      @mutex.synchronize do
        value = read_unlocked(key)
        @store.delete(key)
        @expiries.delete(key)
        value
      end
    end

    def delete(key)
      @mutex.synchronize do
        @store.delete(key)
        @expiries.delete(key)
      end
    end

    def clear!
      @mutex.synchronize do
        @store.clear
        @expiries.clear
      end
    end

    private

    def read_unlocked(key)
      expiry = @expiries[key]
      if expiry && expiry < Time.current
        @store.delete(key)
        @expiries.delete(key)
        return nil
      end
      @store[key]
    end
  end
end
