module Teambuilds
  class Ingest
    Result = Data.define(:ok?, :teambuild, :errors, :created?, :changed?)

    def self.call(player:, source_uuid:, document:, visibility: "private", status: nil)
      new(player: player, source_uuid: source_uuid, document: document,
          visibility: visibility, status: status).call
    end

    def initialize(player:, source_uuid:, document:, visibility:, status:)
      @player = player
      @source_uuid = source_uuid.to_s.downcase
      @document = document
      @visibility = Teambuild::VISIBILITIES.include?(visibility) ? visibility : "private"
      @status = Teambuild::STATUSES.include?(status) ? status : nil
    end

    def call
      errors = Validator.validate(@document)
      return failure(errors) if errors.any?
      unless UUID_RE.match?(@source_uuid)
        return failure([{ "path" => "$", "code" => "invalid_source_uuid",
                          "message" => "L'identifiant doit être un UUID canonique minuscule" }])
      end

      ActiveRecord::Base.transaction do
        existing = @player.teambuilds.find_by(source_uuid: @source_uuid)
        incoming_hash = DocumentHash.of(@document)
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
        success(teambuild, created, true)
      end
    end

    private

    UUID_RE = Validator::UUID_RE

    def failure(errors)
      Result.new(false, nil, errors, false, false)
    end

    def success(teambuild, created, changed)
      Result.new(true, teambuild, [], created, changed)
    end
  end
end
