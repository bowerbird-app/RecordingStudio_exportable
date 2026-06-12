class HomeController < ApplicationController
  def index
    @demo_dashboard = DemoDashboard.includes(:demo_api_requests).first
    @demo_recording = RecordingStudio.root_recording_for(@demo_dashboard) if @demo_dashboard
  end
end
