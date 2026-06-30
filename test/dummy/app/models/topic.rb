class Topic < ApplicationRecord
  recording_studio_recordable label: "Topic", root: false, allowed_parent_types: [ "Article" ]

  belongs_to :article

  def formatted_created_at
    created_at&.in_time_zone&.strftime("%B %d %Y %I:%M %P")
  end
end
