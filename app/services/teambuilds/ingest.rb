module Teambuilds
  class Ingest
    Result = Data.define(:ok?, :teambuild, :errors, :created?, :changed?, :precondition_failed?)

    def self.call(player:, source_uuid:, document:, visibility: "private", status: nil, if_match: nil)
      new(player: player, source_uuid: source_uuid, document: document,
          visibility: visibility, status: status, if_match: if_match).call
    end

    def initialize(player:, source_uuid:, document:, visibility:, status:, if_match:)
      @player = player
      @source_uuid = source_uuid.to_s.downcase
      @document = document
      @visibility = Teambuild::VISIBILITIES.include?(visibility) ? visibility : "private"
      @status = Teambuild::STATUSES.include?(status) ? status : nil
      @if_match = normalize_if_match(if_match)
    end

    def call
      errors = Validator.validate(@document, allowed_tags: TeambuildTag.active_slugs)
      return failure(errors) if errors.any?
      unless UUID_RE.match?(@source_uuid)
        return failure([{ "path" => "$", "code" => "invalid_source_uuid",
                          "message" => "L'identifiant doit être un UUID canonique minuscule" }])
      end

      ActiveRecord::Base.transaction do
        existing = @player.teambuilds.find_by(source_uuid: @source_uuid)
        incoming_hash = DocumentHash.of(@document)

        if @if_match && !etag_matches?(existing)
          return failure([{ "path" => "$", "code" => "precondition_failed",
                            "message" => "If-Match ne correspond pas à l'état actuel du build" }],
                         precondition_failed: true)
        end

        if existing && existing.document_hash == incoming_hash
          existing.update_column(:visibility, @visibility) if existing.visibility != @visibility
          existing.update_column(:status, @status) if @status && existing.status != @status
          return success(existing, false, false)
        end

        created = existing.nil?
        teambuild = existing || @player.teambuilds.new(source_uuid: @source_uuid)
        teambuild.document = @document
        teambuild.visibility = @visibility
        teambuild.status = @status if @status
        Indexer.call(teambuild)
        teambuild.save!
        TeambuildDeletion.where(player_id: @player.id, source_uuid: @source_uuid).delete_all if created
        success(teambuild, created, true)
      end
    end

    private

    UUID_RE = Validator::UUID_RE

    def normalize_if_match(value)
      return unless value.is_a?(String) && value.present?
      value = value.strip
      return "*" if value == "*"
      value.delete_prefix('"').delete_suffix('"')
    end

    def etag_matches?(existing)
      return false if existing.nil?
      return true if @if_match == "*"
      existing.document_hash == @if_match
    end

    def failure(errors, precondition_failed: false)
      Result.new(false, nil, errors, false, false, precondition_failed)
    end

    def success(teambuild, created, changed)
      Result.new(true, teambuild, [], created, changed, false)
    end
  end
end
