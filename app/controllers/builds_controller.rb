class BuildsController < ApplicationController
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
              filename: "#{@teambuild.name.presence&.parameterize.presence || @teambuild.source_uuid}.zcx",
              type: "application/octet-stream",
              disposition: "attachment"
  end

  private

  def set_teambuild
    @teambuild = Teambuild.find_by(id: params[:id])
    redirect_to builds_path, alert: "Build not found or private." if @teambuild.nil? || !@teambuild.visible_to?(current_player)
  end

  def build_rows
    documents = Array(@teambuild.document["characters"])
    @teambuild.teambuild_characters.includes(:primary_profession, :secondary_profession).each_with_index.map do |row, position|
      character = documents[position] || {}
      skills = Array(character["skillIds"]).map { |sid| sid.zero? ? nil : Skill.find_by(skill_id: sid) }
      document_attributes = Array(character["attributes"]).select { |attribute| attribute.is_a?(Hash) }
      {
        summary: row,
        notes: character["notes"],
        skills: skills,
        attributes: document_attributes.map do |attribute|
          { name: Gw1::ReferenceTables::ATTRIBUTE_NAMES[attribute["id"].to_i] || attribute["id"],
            points: attribute["points"] }
        end,
        template_code: template_code_for(row, skills, document_attributes)
      }
    end
  end

  def template_code_for(row, skills, document_attributes)
    return if row.primary_profession.nil? && row.secondary_profession.nil?
    Gw1::TemplateCode.new(
      primary_profession_id: row.primary_profession&.profession_id.to_i,
      secondary_profession_id: row.secondary_profession&.profession_id.to_i,
      skill_ids: skills.map { |skill| skill&.template_skill_id.to_i },
      attributes: document_attributes.map { |a| [a["id"].to_i, a["points"].to_i] }
    ).call
  rescue ArgumentError
    nil
  end
end
