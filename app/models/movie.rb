# == Schema Information
#
# Table name: movies
#
#  id             :integer          not null, primary key
#  player_id      :integer          not null
#  provider       :string
#  video_url      :string
#  movieable_id   :integer
#  movieable_type :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_movies_on_player_id  (player_id)
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
