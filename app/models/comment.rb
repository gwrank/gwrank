# == Schema Information
#
# Table name: comments
#
#  id               :bigint           not null, primary key
#  body             :text
#  commentable_type :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  commentable_id   :integer
#  player_id        :bigint           not null
#
# Indexes
#
#  index_comments_on_player_id  (player_id)
#
# Foreign Keys
#
#  fk_rails_...  (player_id => players.id)
#

class Comment < ApplicationRecord
  belongs_to :player
  belongs_to :commentable, polymorphic: true
end
