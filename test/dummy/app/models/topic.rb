class Topic < ApplicationRecord
  recording_studio_recordable label: "Topic", root: false, allowed_parent_types: [ "Article" ]

  belongs_to :article
end