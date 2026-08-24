class BuildsController < ApplicationController
  layout "gw"

  before_action :set_teambuild, only: [:show, :download]

  def index
    scope = current_player ? Teambuild.visible_to(current_player) : Teambuild.publicly_visible
    scope = scope.with_name_like(params[:q]) if params[:q].present?
    @teambuilds = scope.order(updated_at: :desc).includes(:player, teambuild_characters: :primary_profession).limit(50)
  end

  def show
    @rows = build_rows
  end

  def download
    send_data JSON.pretty_generate(@teambuild.document),
              filename: "#{@teambuild.source_uuid}.zcx",
              type: "application/octet-stream",
              disposition: "attachment"
  end

  private

  def set_teambuild
    @teambuild = Teambuild.find_by(id: params[:id])
    redirect_to builds_path, alert: "Build introuvable ou privé." if @teambuild.nil? || !@teambuild.visible_to?(current_player)
  end

  def build_rows
    documents = Array(@teambuild.document["characters"])
    @teambuild.teambuild_characters.each_with_index.map do |row, position|
      character = documents[position] || {}
      {
        summary: row,
        notes: character["notes"],
        skills: Array(character["skillIds"]).map { |sid| sid.zero? ? nil : Skill.find_by(skill_id: sid) },
        attributes: Array(character["attributes"]).select { |attribute| attribute.is_a?(Hash) }.map do |attribute|
          { name: Gw1::ReferenceTables::ATTRIBUTE_NAMES[attribute["id"].to_i] || attribute["id"],
            points: attribute["points"] }
        end
      }
    end
  end
end
