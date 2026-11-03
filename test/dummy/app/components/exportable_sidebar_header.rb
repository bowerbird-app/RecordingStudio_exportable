# frozen_string_literal: true

# Sidebar::Header badges FlatPack::VERSION. The dummy badge is this gem.
class ExportableSidebarHeader < FlatPack::Sidebar::Header::Component
  def initialize(version:, **system_arguments)
    @gem_version = version
    super(**system_arguments)
  end

  private

  def sidebar_version_label
    "v#{@gem_version}"
  end
end
