module Teambuilds
  class Ingest
    Result = Data.define(:ok?, :teambuild, :errors, :created?, :changed?)

    def self.call(player:, source_uuid:, document:, visibility: "private")
      new(player: player, source_uuid: source_uuid, document: document,
          visibility: visibility).call
    end

    def initialize(player:, source_uuid:, document:, visibility:)
      @player = player
      @source_uuid = source_uuid.to_s.downcase
      @document = document
      @visibility = Teambuild::VISIBILITIES.include?(visibility) ? visibility : "private"
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
        return success(existing, false, false) if existing && existing.document_hash == incoming_hash

        created = existing.nil?
        teambuild = existing || @player.teambuilds.new(source_uuid: @source_uuid)
        teambuild.document = @document
        teambuild.visibility = @visibility
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
