class BuildsController < ApplicationController
  before_action :set_teambuild, only: [:show, :download]

  def index
    scope = current_player ? Teambuild.visible_to(current_player) : Teambuild.publicly_visible
    scope = scope.with_name_like(params[:q]) if params[:q].present?
    @teambuilds = scope.order(updated_at: :desc).includes(:player, teambuild_characters: :primary_profession).limit(50)
  end

  def show
    @compositions = Teambuilds::Compositions.of(@teambuild.document).map do |composition|
      composition.merge(rows: composition[:characters].map { |node| build_row(node) })
    end
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

  def build_row(character)
    skills = Array(character["skillIds"]).map { |sid| skill_for(sid) }
    document_attributes = Array(character["attributes"]).select { |attribute| attribute.is_a?(Hash) }
    primary_profession = profession_for(character["primaryProfession"])
    secondary_profession = profession_for(character["secondaryProfession"])
    {
      name: character["name"].to_s,
      assignment: character["assignment"].to_s,
      notes: character["notes"],
      primary_profession: primary_profession,
      secondary_profession: secondary_profession,
      skills: skills,
      attributes: document_attributes.map do |attribute|
        { name: Gw1::ReferenceTables::ATTRIBUTE_NAMES[attribute["id"].to_i] || attribute["id"],
          points: attribute["points"] }
      end,
      template_code: template_code_for(primary_profession, secondary_profession, skills, document_attributes)
    }
  end

  def skill_for(skill_id)
    skill_id.to_i.zero? ? nil : skills_by_id[skill_id]
  end

  def profession_for(code)
    return if code.nil? || code.to_i.zero?

    professions_by_code[code.to_i]
  end

  def skills_by_id
    @skills_by_id ||= Hash.new { |hash, skill_id| hash[skill_id] = Skill.find_by(skill_id: skill_id) }
  end

  def professions_by_code
    @professions_by_code ||= Hash.new { |hash, code| hash[code] = Profession.find_by(profession_id: code) }
  end

  def template_code_for(primary_profession, secondary_profession, skills, document_attributes)
    return if primary_profession.nil? && secondary_profession.nil?

    Gw1::TemplateCode.new(
      primary_profession_id: primary_profession&.profession_id.to_i,
      secondary_profession_id: secondary_profession&.profession_id.to_i,
      skill_ids: skills.map { |skill| skill&.template_skill_id.to_i },
      attributes: document_attributes.map { |a| [a["id"].to_i, a["points"].to_i] }
    ).call
  rescue ArgumentError
    nil
  end
end
