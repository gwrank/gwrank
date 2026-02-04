class Api::V1::ItemsController < ApplicationController
  before_action :set_item, only: [:show]

  def index
    @items = Item.whose_title_starts_with(params[:q])
    render json: @items
  end

  def show
    render json: @item
  end

  private

  def set_item
    @item = Item.friendly.find(params[:id])
  end
end
