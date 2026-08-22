class Api::V1::TeambuildsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_api_token

  rescue_from ActionDispatch::Http::Parameters::ParseError do
    render_malformed_json
  end

  PER_PAGE_DEFAULT = 25
  PER_PAGE_MAX = 100

  def index
    relation = filtered(Teambuild.visible_to(@player))
    total_count = relation.distinct.count
    records = relation.includes(teambuild_characters: [:primary_profession, :secondary_profession, :elite_skill])
                      .order(Teambuild::SORTS.fetch(params[:sort], Teambuild::SORTS.fetch("updated_at")))
                      .limit(per_page).offset(offset)

    render json: {
      teambuilds: records.map(&:summary),
      pagination: { page: page_number, perPage: per_page, totalCount: total_count }
    }
  end

  def show
    teambuild = resolve_teambuild(params[:id])
    return head :not_found if teambuild.nil?
    return head :forbidden unless teambuild.visible_to?(@player)

    render json: teambuild.document
  end

  def update
    return render_invalid_source_uuid unless valid_source_uuid?

    document = parse_document
    return if performed?

    result = begin
      Teambuilds::Ingest.call(
        player: @player,
        source_uuid: source_uuid_param,
        document: document,
        visibility: params[:visibility]
      )
    rescue ActiveRecord::RecordNotUnique
      Teambuilds::Ingest.call(
        player: @player,
        source_uuid: source_uuid_param,
        document: document,
        visibility: params[:visibility]
      )
    end

    if result.ok?
      payload = result.teambuild.summary.merge(created: result.created?, changed: result.changed?)
      render json: payload, status: result.created? ? :created : :ok
    else
      render json: { errors: result.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    teambuild = resolve_teambuild(params[:id])
    return head :not_found if teambuild.nil?
    return head :forbidden unless teambuild.player_id == @player.id

    teambuild.destroy!
    head :no_content
  end

  private

  def verify_api_token
    authenticate_or_request_with_http_token do |token, _options|
      @player = Player.find_by(api_token: token)
    end
  end

  def parse_document
    JSON.parse(request.raw_post)
  rescue JSON::ParserError
    render_malformed_json
    nil
  end

  def render_malformed_json
    render json: { errors: [{ "path" => "$", "code" => "malformed_json",
                              "message" => "Corps de requête illisible" }] }, status: :bad_request
  end

  def valid_source_uuid?
    Teambuilds::Validator::UUID_RE.match?(source_uuid_param.to_s)
  end

  def source_uuid_param
    params[:source_uuid].presence || params[:id]
  end

  def render_invalid_source_uuid
    render json: { errors: [{ "path" => "$", "code" => "invalid_source_uuid",
                              "message" => "L'identifiant doit être un UUID canonique minuscule" }] },
           status: :bad_request
  end

  def resolve_teambuild(value)
    value = value.to_s
    if value.match?(Teambuilds::Validator::UUID_RE)
      Teambuild.find_by(source_uuid: value)
    elsif value.match?(/\A\d+\z/)
      Teambuild.find_by(id: value)
    end
  end

  def filtered(relation)
    relation = relation.with_name_like(params[:q]) if params[:q].present?
    relation = relation.tagged_with_any(params[:tags]) if params[:tags].present?
    relation = relation.with_profession_code(params[:profession_id]) if params[:profession_id].present?
    relation = relation.with_skill_id(params[:elite_skill_id]) if params[:elite_skill_id].present?
    relation = relation.with_campaign(params[:campaign]) if params[:campaign].present?
    relation = relation.with_game_mode(params[:game_mode]) if params[:game_mode].present?
    relation = apply_player_count_range(relation)
    relation = relation.owned_by(@player) if params[:visibility] == "mine"
    relation
  end

  def apply_player_count_range(relation)
    min = params[:player_count_min].presence&.to_i
    max = params[:player_count_max].presence&.to_i
    return relation unless min || max
    range = min && max ? min..max : (min ? min.. : ..max)
    relation.where(player_count: range)
  end

  def page_number
    [params[:page].to_i, 1].max
  end

  def per_page
    params.fetch(:per_page, PER_PAGE_DEFAULT).to_i.clamp(1, PER_PAGE_MAX)
  end

  def offset
    (page_number - 1) * per_page
  end
end
