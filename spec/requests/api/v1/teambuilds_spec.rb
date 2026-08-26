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
    raise "seed ingest failed: #{result.errors.inspect}" unless result.ok?
  end

  path '/api/v1/teambuilds' do
    get 'Search teambuilds' do
      produces 'application/json'
      description <<~DESC.squish
        Paginated list of summaries of everything the caller can see:
        publics + their own, including others' public drafts.
      DESC

      parameter name: :q, in: :query, schema: { type: :string }, description: 'Name, case-insensitive'
      parameter name: 'tags[]', in: :query, getter: :tag_filters,
                schema: { type: :array, items: { type: :string } }, description: 'Array overlap'
      parameter name: :profession_id, in: :query, schema: { type: :integer },
                description: 'Official GW1 profession code (0-10)'
      parameter name: :elite_skill_id, in: :query, schema: { type: :integer },
                description: 'Official GW1 skill id'
      parameter name: :campaign, in: :query, schema: { type: :string }
      parameter name: :game_mode, in: :query, schema: { type: :string, enum: ['All', 'PvE', 'PvP', ''] }
      parameter name: :player_count_min, in: :query, schema: { type: :integer, minimum: 1 }
      parameter name: :player_count_max, in: :query, schema: { type: :integer, maximum: 12 }
      parameter name: :visibility, in: :query,
                schema: { type: :string, enum: %w[all mine public] },
                description: 'all: everything visible to the caller (default); mine: own builds only; public: publicly visible only'
      parameter name: :status, in: :query, schema: { type: :string, enum: %w[draft published] }
      parameter name: :sort, in: :query, schema: { type: :string, enum: %w[updated_at name player_count] }
      parameter name: :page, in: :query, schema: { type: :integer, minimum: 1 }
      parameter name: :per_page, in: :query, schema: { type: :integer, minimum: 1, maximum: 100 }
      parameter name: :updated_since, in: :query, required: false,
                schema: { type: :string, format: :'date-time' },
                description: 'ISO 8601 instant; only builds updated at or after it are returned. ' \
                             'The response also carries deletions[] (sourceId/deletedAt) listing builds removed since then.'

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

      response(200, 'visibility=public keeps only publicly visible builds') do
        before do
          @owner = create_api_player
          @other = create_api_player
          seed_build(@owner, zcx)
          seed_build(@other, zcx_variant('aaaaaaa1-0000-0000-0000-000000000002', name: 'Public Meta'),
                     visibility: 'public')
        end
        let(:visibility) { 'public' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.dig('pagination', 'totalCount')).to eq(1)
          authors = data['teambuilds'].map { |build| build['author'] }
          expect(authors).to contain_exactly(@other.username)
        end
      end

      response(200, 'visibility=all lists everything the caller can see') do
        before do
          @owner = create_api_player
          @other = create_api_player
          seed_build(@owner, zcx)
          seed_build(@other, zcx_variant('aaaaaaa1-0000-0000-0000-000000000003', name: 'Public Meta'),
                     visibility: 'public')
        end
        let(:visibility) { 'all' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.dig('pagination', 'totalCount')).to eq(2)
          authors = data['teambuilds'].map { |build| build['author'] }
          expect(authors).to contain_exactly(@owner.username, @other.username)
        end
      end

      response(200, 'visibility=mine keeps only own builds') do
        before do
          @owner = create_api_player
          @other = create_api_player
          seed_build(@owner, zcx)
          seed_build(@other, zcx_variant('aaaaaaa1-0000-0000-0000-000000000004', name: 'Public Meta'),
                     visibility: 'public')
        end
        let(:visibility) { 'mine' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.dig('pagination', 'totalCount')).to eq(1)
          authors = data['teambuilds'].map { |build| build['author'] }
          expect(authors).to contain_exactly(@owner.username)
        end
      end

      response(200, 'updated_since also reports deletions since the instant') do
        before do
          @owner = create_api_player
          @other = create_api_player
          seed_build(@owner, zcx)
          seed_build(@other, zcx_variant('aaaaaaa1-0000-0000-0000-000000000005'), visibility: 'public')
          seed_build(@other, zcx_variant('aaaaaaa1-0000-0000-0000-000000000006'))
          @since = Time.current.change(usec: 0)
          Teambuild.find_by!(source_uuid: zcx['id']).destroy!
          Teambuild.find_by!(source_uuid: 'aaaaaaa1-0000-0000-0000-000000000005').destroy!
          Teambuild.find_by!(source_uuid: 'aaaaaaa1-0000-0000-0000-000000000006').destroy!
        end
        let(:updated_since) { @since.iso8601 }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['teambuilds']).to be_empty
          removed = data['deletions'].map { |entry| entry['sourceId'] }
          expect(removed).to contain_exactly(zcx['id'], 'aaaaaaa1-0000-0000-0000-000000000005')
        end
      end

      response(200, 'Paginated list of summaries') do
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
            deletions: { type: :array, items: { '$ref': '#/components/schemas/TeambuildDeletion' } },
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

      response(401, 'Missing or invalid token') do
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
    get 'Export all visible teambuilds in one call' do
      produces 'application/json'
      description <<~DESC.squish
        Enriched summaries carrying the complete .zcx document for everything the caller
        can see: publics + their own, including public drafts (filterable via status).
        Single response, no pagination.
      DESC

      parameter name: :status, in: :query, schema: { type: :string, enum: %w[draft published] }
      parameter name: :updated_since, in: :query, required: false,
                schema: { type: :string, format: :'date-time' },
                description: 'ISO 8601 instant; only builds updated at or after it are returned. ' \
                             'The response also carries deletions[] (sourceId/deletedAt) listing builds removed since then.'

      let(:Authorization) { "Bearer #{@owner.api_token}" }
      let(:status) { nil }
      let(:updated_since) { nil }

      response(200, 'updated_since also reports deletions since the instant') do
        before do
          @owner = create_api_player
          @other = create_api_player
          seed_build(@owner, zcx)
          seed_build(@other, zcx_variant('aaaaaaa1-0000-0000-0000-000000000010'), visibility: 'public')
          seed_build(@other, zcx_variant('aaaaaaa1-0000-0000-0000-000000000011'))
          @since = Time.current.change(usec: 0)
          Teambuild.find_by!(source_uuid: zcx['id']).destroy!
          Teambuild.find_by!(source_uuid: 'aaaaaaa1-0000-0000-0000-000000000010').destroy!
          Teambuild.find_by!(source_uuid: 'aaaaaaa1-0000-0000-0000-000000000011').destroy!
        end
        let(:updated_since) { @since.iso8601 }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['teambuilds']).to be_empty
          removed = data['deletions'].map { |entry| entry['sourceId'] }
          expect(removed).to contain_exactly(zcx['id'], 'aaaaaaa1-0000-0000-0000-000000000010')
        end
      end

      response(200, 'Every visible teambuild') do
        before do
          @owner = create_api_player
          @other = create_api_player
          seed_build(@owner, zcx)
          seed_build(@other, zcx_variant('aaaaaaa1-0000-0000-0000-000000000009'), visibility: 'public')
        end

        schema(
          type: :object,
          properties: {
            teambuilds: { type: :array, items: { '$ref': '#/components/schemas/TeambuildExport' } },
            deletions: { type: :array, items: { '$ref': '#/components/schemas/TeambuildDeletion' } }
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

      response(401, 'Missing or invalid token') do
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
    get 'Fetch one full teambuild' do
      produces 'application/json'
      description <<~DESC.squish
        Returns the stored .zcx document, intact, merged with a root-level author key
        (owner account name). Accepts the server id or the source_uuid (the .zcx id).
        Key order may differ from the original; semantic content is identical. Responds
        with a strong ETag header equal to the quoted documentHash.
      DESC

      parameter name: :id, in: :path, required: true, schema: { type: :string },
                description: 'Server id or lowercase canonical source_uuid'

      let(:Authorization) { "Bearer #{@owner.api_token}" }
      let(:id) { zcx['id'] }

      response(200, 'Complete .zcx document') do
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
                author: { type: :string, description: "Owner account name (@username without the @)" }
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

      response(404, 'Not found') do
        let(:id) { 'ccccccc1-0000-0000-0000-000000000001' }
        before { @owner = create_api_player }
        run_test!
      end

      response(403, "Someone else's private build, or unauthorized write") do
        before do
          @other = create_api_player
          seed_build(create_api_player, zcx)
        end
        let(:Authorization) { "Bearer #{@other.api_token}" }
        run_test!
      end

      response(401, 'Missing or invalid token') do
        let(:Authorization) { '' }
        run_test!
      end
    end

    put 'Create or replace a teambuild (file-by-file sync)' do
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
                description: 'Status kept as-is when omitted'
      parameter name: :document, in: :body, required: true,
                schema: { '$ref': '#/components/schemas/ZcxDocument' },
                description: 'Raw .zcx document'
      request_body_example value: { '$ref': '#/components/examples/GvgSplit' },
                           summary: 'Single-character teambuild with variant/lock/spike (format §12)',
                           name: :gvgSplit

      let(:Authorization) { "Bearer #{@owner.api_token}" }
      let(:id) { 'eeeeeee1-0000-0000-0000-000000000001' }
      let(:document) { zcx_variant(id) }
      let(:visibility) { nil }
      let(:status) { nil }
      let(:if_match) { nil }

      response(201, 'Created') do
        before { @owner = create_api_player }

        schema({ '$ref': '#/components/schemas/UpsertResult' })

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body['created']).to eq(true)
          expect(body['author']).to eq(@owner.username)
        end
      end

      response(200, 'Replaced or unchanged (see created/changed)') do
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

      response(400, 'Malformed JSON or invalid identifier') do
        let(:id) { 'not-a-uuid' }
        before { @owner = create_api_player }

        schema({ '$ref': '#/components/schemas/ErrorList' })

        run_test! do |response|
          codes = JSON.parse(response.body)['errors'].map { |error| error['code'] }
          expect(codes).to include('invalid_source_uuid')
        end
      end

      response(422, 'Format rule violation (see docs/zcx_format.md §11)') do
        let(:document) { zcx_variant(id, author: 'spoofed-author') }
        before { @owner = create_api_player }

        schema({ '$ref': '#/components/schemas/ErrorList' })

        run_test! do |response|
          codes = JSON.parse(response.body)['errors'].map { |error| error['code'] }
          expect(codes).to include('reserved_key')
        end
      end

      response(401, 'Missing or invalid token') do
        let(:Authorization) { '' }
        run_test!
      end
    end

    delete 'Delete one of your own teambuilds' do
      parameter name: :id, in: :path, required: true, schema: { type: :string },
                description: 'Server id or lowercase canonical source_uuid'

      let(:Authorization) { "Bearer #{@owner.api_token}" }
      let(:id) { zcx['id'] }

      response(204, 'Deleted') do
        before do
          @owner = create_api_player
          seed_build(@owner, zcx)
        end

        run_test! do |_response|
          expect(Teambuild.count).to eq(0)
        end
      end

      response(403, "Someone else's private build, or unauthorized write") do
        before do
          seed_build(create_api_player, zcx)
          @other = create_api_player
        end
        let(:Authorization) { "Bearer #{@other.api_token}" }

        run_test! do |_response|
          expect(Teambuild.count).to eq(1)
        end
      end

      response(404, 'Not found') do
        let(:id) { 'ccccccc1-0000-0000-0000-000000000002' }
        before { @owner = create_api_player }
        run_test!
      end

      response(401, 'Missing or invalid token') do
        let(:Authorization) { '' }
        run_test!
      end
    end
  end
end
