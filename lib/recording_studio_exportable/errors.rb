# frozen_string_literal: true

module RecordingStudioExportable
  class Error < StandardError; end
  class InvalidExportDefinition < Error; end
  class DuplicateExportDefinition < Error; end
  class NotAuthorized < Error; end
  class UnknownExportKey < Error; end
  class ExportNotAllowedForContext < Error; end
  class InvalidExportColumns < Error; end
  class InvalidExportAttributes < Error; end
  class InvalidExportFormat < Error; end
  class ExportTooLarge < Error; end

  # Backward-compatible aliases for earlier template tests/apps.
  UnknownExportDefinition = UnknownExportKey
  AuthorizationError = NotAuthorized
  RowLimitExceeded = ExportTooLarge
end
