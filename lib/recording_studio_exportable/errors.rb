# frozen_string_literal: true

module RecordingStudioExportable
  class Error < StandardError; end
  class InvalidExportDefinition < Error; end
  class DuplicateExportDefinition < Error; end
  class UnknownExportDefinition < Error; end
  class AuthorizationError < Error; end
  class RowLimitExceeded < Error; end
end
