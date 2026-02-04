# == Schema Information
#
# Table name: movies
#
#  id             :bigint           not null, primary key
#  movieable_type :string
#  provider       :string
#  video_url      :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  movieable_id   :integer
#  player_id      :bigint           not null
#
# Indexes
#
#  index_movies_on_player_id  (player_id)
#
# Foreign Keys
#
#  fk_rails_...  (player_id => players.id)
#

class Movie < ApplicationRecord
  belongs_to :player
  belongs_to :movieable, polymorphic: true

  def youtube_embed_id
    youtube_embed_id = video_url.split('/').last
    if youtube_embed_id.include?('=')
      youtube_embed_id = youtube_embed_id.split('=').last
    end
    youtube_embed_id
  end
end
