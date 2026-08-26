class Api::V1::TagsController < ApplicationController
  def index
    response.set_header("Cache-Control", "public, max-age=300")
    render json: { tags: TeambuildTag.active.ordered.pluck(:name) }
  end
end
