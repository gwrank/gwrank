# == Schema Information
#
# Table name: comments
#
#  id               :integer          not null, primary key
#  player_id        :integer          not null
#  body             :text
#  commentable_id   :integer
#  commentable_type :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_comments_on_player_id  (player_id)
#

class Comment < ApplicationRecord
  belongs_to :player
  belongs_to :commentable, polymorphic: true
end
