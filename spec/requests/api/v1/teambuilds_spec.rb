# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Teambuilds API', swagger_doc: 'teambuilds.yaml', type: :request do
  let(:zcx) { load_zcx }

  def zcx_variant(uuid, **overrides)
    JSON.parse(zcx.to_json).merge('id' => uuid).merge(overrides.transform_keys(&:to_s))
  end

  def seed_build(player, document, visibility: 'private', status: nil)
    result = Teambuilds::Ingest.call(
      player: player,
      source_uuid: document['id'],
      document: document,
      visibility: visibility,
      status: status
    )
    raise "seed ingest a échoué : #{result.errors.inspect}" unless result.ok?
  end

  path '/api/v1/teambuilds' do
    get 'Rechercher des teambuilds' do
      produces 'application/json'
      description <<~DESC.squish
        Liste paginée de résumés de tout ce que l'appelant peut voir :
        publics + les siens, drafts publics compris.
      DESC

      parameter name: :q, in: :query, schema: { type: :string }, description: 'Nom, insensible à la casse'
      parameter name: 'tags[]', in: :query, getter: :tag_filters,
                schema: { type: :array, items: { type: :string } }, description: 'Recouvrement'
      parameter name: :profession_id, in: :query, schema: { type: :integer },
                description: 'Code de profession GW1 officiel (0–10)'
      parameter name: :elite_skill_id, in: :query, schema: { type: :integer },
                description: 'SkillId GW1 officiel'
      parameter name: :campaign, in: :query, schema: { type: :string }
      parameter name: :game_mode, in: :query, schema: { type: :string, enum: ['All', 'PvE', 'PvP', ''] }
      parameter name: :player_count_min, in: :query, schema: { type: :integer, minimum: 1 }
      parameter name: :player_count_max, in: :query, schema: { type: :integer, maximum: 12 }
      parameter name: :visibility, in: :query, schema: { type: :string, enum: ['mine'] }
      parameter name: :status, in: :query, schema: { type: :string, enum: %w[draft published] }
      parameter name: :sort, in: :query, schema: { type: :string, enum: %w[updated_at name player_count] }
      parameter name: :page, in: :query, schema: { type: :integer, minimum: 1 }
      parameter name: :per_page, in: :query, schema: { type: :integer, minimum: 1, maximum: 100 }
      parameter name: :updated_since, in: :query, required: false,
                schema: { type: :string, format: :'date-time' },
                description: 'ISO 8601 instant; only builds updated at or after it are returned'

      let(:Authorization) { "Bearer #{@owner.api_token}" }
      let(:q) { nil }
      let(:tag_filters) { [] }
      let(:profession_id) { nil }
      let(:elite_skill_id) { nil }
      let(:campaign) { nil }
      let(:game_mode) { nil }
      let(:player_count_min) { nil }
      let(:player_count_max) { nil }
      let(:visibility) { nil }
      let(:status) { nil }
      let(:sort) { nil }
      let(:page) { 1 }
      let(:per_page) { 25 }
      let(:updated_since) { nil }

      response(200, 'Liste paginée de résumés') do
        before do
          @owner = create_api_player
          @other = create_api_player
          seed_build(@owner, zcx)
          seed_build(@other, zcx_variant('aaaaaaa1-0000-0000-0000-000000000001', name: 'Public Meta'),
                     visibility: 'public')
        end

        schema(
          type: :object,
          properties: {
            teambuilds: { type: :array, items: { '$ref': '#/components/schemas/TeambuildSummary' } },
            pagination: { '$ref': '#/components/schemas/Pagination' }
          }
        )

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.dig('pagination', 'totalCount')).to eq(2)
          authors = data['teambuilds'].map { |build| build['author'] }
          expect(authors).to contain_exactly(@owner.username, @other.username)
        end
      end

      response(401, 'Token absent ou invalide') do
        let(:Authorization) { '' }
        run_test!
      end

      response(400, 'Malformed updated_since') do
        before { @owner = create_api_player }
        let(:updated_since) { 'yesterday' }

        schema({ '$ref': '#/components/schemas/ErrorList' })

        run_test! do |response|
          codes = JSON.parse(response.body)['errors'].map { |e| e['code'] }
          expect(codes).to include('invalid_updated_since')
        end
      end
    end
  end

  path '/api/v1/teambuilds/export' do
    get 'Exporter tous les teambuilds visibles en un appel' do
      produces 'application/json'
      description <<~DESC.squish
        Résumés enrichis du document .zcx intégral pour tout ce que l'appelant
        peut voir : publics + les siens, drafts publics compris (filtrables via
        status). Réponse unique, sans pagination.
      DESC

      parameter name: :status, in: :query, schema: { type: :string, enum: %w[draft published] }
      parameter name: :updated_since, in: :query, required: false,
                schema: { type: :string, format: :'date-time' },
                description: 'ISO 8601 instant; only builds updated at or after it are returned'

      let(:Authorization) { "Bearer #{@owner.api_token}" }
      let(:status) { nil }
      let(:updated_since) { nil }

      response(200, 'Liste complète des teambuilds visibles') do
        before do
          @owner = create_api_player
          @other = create_api_player
          seed_build(@owner, zcx)
          seed_build(@other, zcx_variant('aaaaaaa1-0000-0000-0000-000000000009'), visibility: 'public')
        end

        schema(
          type: :object,
          properties: {
            teambuilds: { type: :array, items: { '$ref': '#/components/schemas/TeambuildExport' } }
          }
        )

        run_test! do |response|
          entries = JSON.parse(response.body)['teambuilds']
          expect(entries.map { |entry| entry['sourceId'] })
            .to contain_exactly(zcx['id'], 'aaaaaaa1-0000-0000-0000-000000000009')
          entries.each do |entry|
            expect(entry.keys).to include('author', 'document')
          end
          expect(entries.min_by { |entry| entry['sourceId'] == zcx['id'] ? 0 : 1 }['document']).to eq(zcx)
        end
      end

      response(401, 'Token absent ou invalide') do
        let(:Authorization) { '' }
        run_test!
      end

      response(400, 'Malformed updated_since') do
        before { @owner = create_api_player }
        let(:updated_since) { 'yesterday' }

        schema({ '$ref': '#/components/schemas/ErrorList' })

        run_test! do |response|
          codes = JSON.parse(response.body)['errors'].map { |e| e['code'] }
          expect(codes).to include('invalid_updated_since')
        end
      end
    end
  end

  path '/api/v1/teambuilds/{id}' do
    get 'Récupérer un teambuild complet' do
      produces 'application/json'
      description <<~DESC.squish
        Renvoie le document .zcx stocké, intact, fusionné avec une clé racine
        author (nom du compte propriétaire). Accepte l'id serveur ou le
        source_uuid (l'id du .zcx). L'ordre des clés peut différer de
        l'original ; le contenu sémantique est identique.
      DESC

      parameter name: :id, in: :path, required: true, schema: { type: :string },
                description: 'Id serveur ou source_uuid canonique minuscule'

      let(:Authorization) { "Bearer #{@owner.api_token}" }
      let(:id) { zcx['id'] }

      response(200, 'Document .zcx complet') do
        before do
          @owner = create_api_player
          seed_build(@owner, zcx)
          @server_id = Teambuild.find_by!(source_uuid: zcx['id']).id.to_s
        end
        let(:id) { @server_id }

        example('application/json', :gvgSplit, '$ref': '#/components/examples/GvgSplit')

        header 'ETag',
               description: 'Strong entity tag: quoted SHA-256 document hash. Use it as If-Match on PUT.',
               schema: { type: :string }

        schema(
          allOf: [
            { '$ref': '#/components/schemas/ZcxDocument' },
            {
              type: :object,
              properties: {
                author: { type: :string, description: "Nom d'utilisateur du propriétaire (@username sans @)" }
              }
            }
          ]
        )

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body['author']).to eq(@owner.username)
          expect(body.except('author')).to eq(zcx)
        end
      end

      response(404, 'Introuvable') do
        let(:id) { 'ccccccc1-0000-0000-0000-000000000001' }
        before { @owner = create_api_player }
        run_test!
      end

      response(403, "Build privé d'autrui ou écriture non autorisée") do
        before do
          @other = create_api_player
          seed_build(create_api_player, zcx)
        end
        let(:Authorization) { "Bearer #{@other.api_token}" }
        run_test!
      end

      response(401, 'Token absent ou invalide') do
        let(:Authorization) { '' }
        run_test!
      end
    end

    put 'Créer ou remplacer un teambuild (sync fichier par fichier)' do
      produces 'application/json'
      consumes 'application/json'
      description <<~DESC.squish
        Body is the raw .zcx document. Idempotent upsert keyed by (owner, source_uuid):
        create when absent; no-op when the content hash (updatedAt excluded) is unchanged;
        full replace otherwise. Only the lowercase canonical source_uuid is accepted in the
        path — server numeric ids are rejected here (they cannot identify a not-yet-created
        build). visibility and status ride as query params, defaults private/published.
        Optional optimistic locking: send the previously-read documentHash as a quoted
        If-Match header (or * to require existence); on mismatch the write is refused with
        412 and nothing changes. Nesting limit enforced by max_depth: a root character sits
        at depth 0 and any node deeper than 64 levels is rejected.
      DESC

      parameter name: :id, in: :path, required: true, schema: { type: :string, format: :uuid },
                description: 'Lowercase canonical source_uuid only'
      parameter name: :'If-Match', in: :header, required: false, getter: :if_match,
                schema: { type: :string },
                description: 'Optional optimistic lock: quoted documentHash from a previous read, or * to require existence'
      parameter name: :visibility, in: :query,
                schema: { type: :string, enum: %w[private public], default: 'private' }
      parameter name: :status, in: :query,
                schema: { type: :string, enum: %w[draft published], default: 'published' },
                description: 'Statut conservé si absent'
      parameter name: :document, in: :body, required: true,
                schema: { '$ref': '#/components/schemas/ZcxDocument' },
                description: 'Document .zcx brut'
      request_body_example value: { '$ref': '#/components/examples/GvgSplit' },
                           summary: 'Teambuild mono-personnage avec variante/cadenas/spike (format §12)',
                           name: :gvgSplit

      let(:Authorization) { "Bearer #{@owner.api_token}" }
      let(:id) { 'eeeeeee1-0000-0000-0000-000000000001' }
      let(:document) { zcx_variant(id) }
      let(:visibility) { nil }
      let(:status) { nil }
      let(:if_match) { nil }

      response(201, 'Créé') do
        before { @owner = create_api_player }

        schema({ '$ref': '#/components/schemas/UpsertResult' })

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body['created']).to eq(true)
          expect(body['author']).to eq(@owner.username)
        end
      end

      response(200, 'Remplacé ou inchangé (voir created/changed)') do
        before do
          @owner = create_api_player
          seed_build(@owner, zcx_variant(id))
        end
        let(:document) { zcx_variant(id, name: 'GvG Split v2') }

        schema({ '$ref': '#/components/schemas/UpsertResult' })

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body['created']).to eq(false)
          expect(body['changed']).to eq(true)
          expect(body['name']).to eq('GvG Split v2')
          expect(body['author']).to eq(@owner.username)
        end
      end

      response(412, 'Precondition failed (stale If-Match)') do
        before do
          @owner = create_api_player
          seed_build(@owner, zcx_variant(id))
        end
        let(:document) { zcx_variant(id, name: 'GvG Split v2') }
        let(:if_match) { '"deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"' }

        schema({ '$ref': '#/components/schemas/ErrorList' })

        run_test! do |response|
          codes = JSON.parse(response.body)['errors'].map { |error| error['code'] }
          expect(codes).to include('precondition_failed')
        end
      end

      response(400, 'JSON malformé ou identifiant invalide') do
        let(:id) { 'not-a-uuid' }
        before { @owner = create_api_player }

        schema({ '$ref': '#/components/schemas/ErrorList' })

        run_test! do |response|
          codes = JSON.parse(response.body)['errors'].map { |error| error['code'] }
          expect(codes).to include('invalid_source_uuid')
        end
      end

      response(422, 'Violation des règles du format (cf. docs/zcx_format.md §11)') do
        let(:document) { zcx_variant(id, author: 'auteur-spoofé') }
        before { @owner = create_api_player }

        schema({ '$ref': '#/components/schemas/ErrorList' })

        run_test! do |response|
          codes = JSON.parse(response.body)['errors'].map { |error| error['code'] }
          expect(codes).to include('reserved_key')
        end
      end

      response(401, 'Token absent ou invalide') do
        let(:Authorization) { '' }
        run_test!
      end
    end

    delete 'Supprimer un de ses teambuilds' do
      parameter name: :id, in: :path, required: true, schema: { type: :string },
                description: 'Id serveur ou source_uuid canonique minuscule'

      let(:Authorization) { "Bearer #{@owner.api_token}" }
      let(:id) { zcx['id'] }

      response(204, 'Supprimé') do
        before do
          @owner = create_api_player
          seed_build(@owner, zcx)
        end

        run_test! do |_response|
          expect(Teambuild.count).to eq(0)
        end
      end

      response(403, "Build privé d'autrui ou écriture non autorisée") do
        before do
          seed_build(create_api_player, zcx)
          @other = create_api_player
        end
        let(:Authorization) { "Bearer #{@other.api_token}" }

        run_test! do |_response|
          expect(Teambuild.count).to eq(1)
        end
      end

      response(404, 'Introuvable') do
        let(:id) { 'ccccccc1-0000-0000-0000-000000000002' }
        before { @owner = create_api_player }
        run_test!
      end

      response(401, 'Token absent ou invalide') do
        let(:Authorization) { '' }
        run_test!
      end
    end
  end
end
