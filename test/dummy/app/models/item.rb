class Item < ApplicationRecord
  recording_studio_recordable label: "Item", root: false, allowed_parent_types: ["Document"]

  belongs_to :document
end
