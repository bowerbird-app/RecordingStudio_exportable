# frozen_string_literal: true

RecordingStudioExportable::Engine.routes.draw do
  resources :exports, only: :create
end
