class Comment < ApplicationRecord
  belongs_to :player
  belongs_to :commentable, polymorphic: true
end
