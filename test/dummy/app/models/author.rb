class Author < ApplicationRecord
  recording_studio_recordable label: "Author", root: false, allowed_parent_types: [ "Article" ]

  has_many :articles, dependent: :restrict_with_error
end