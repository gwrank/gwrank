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
