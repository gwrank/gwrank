class Api::V1::Items::SearchesController < ApplicationController
  def create
    @items = Item.whose_title_starts_with(params[:q])
    render json: @items
  end
end
