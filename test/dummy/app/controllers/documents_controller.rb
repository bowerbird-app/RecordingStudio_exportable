class DocumentsController < ApplicationController
  before_action :set_document
  before_action :set_document_recording
  before_action :authorize_document_admin!

  def show
    @items = @document.items.order(:name)
  end

  private

  def set_document
    @document = Document.find(params[:id])
  end

  def set_document_recording
    @document_recording = RecordingStudio::Recording.find_by(recordable: @document)
    @document_recording ||= RecordingStudio.root_recording_for(@document)
  end

  def authorize_document_admin!
    allowed = RecordingStudioAccessible.authorized?(
      actor: Current.actor,
      recording: @document_recording,
      role: :admin
    )
    return if allowed

    head :forbidden
  end
end
