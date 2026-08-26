# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Tags API', swagger_doc: 'teambuilds.yaml', type: :request do
  path '/api/v1/tags' do
    get 'List allowed teambuild tags' do
      produces 'application/json'
      security []
      description <<~DESC.squish
        Closed list of tags accepted when publishing teambuilds. Public endpoint (no bearer token).
        Maintained by GWRank administrators; clients should refresh periodically (Cache-Control max-age=300).
      DESC

      response(200, 'returns active tags ordered by position') do
        before do
          TeambuildTag.delete_all
          %w[GvG HA RA TA AB FA JQ PvP PvE].each_with_index do |name, index|
            TeambuildTag.create!(name: name, slug: name.downcase, position: index + 1)
          end
          TeambuildTag.create!(name: 'Legacy', slug: 'legacy', position: 10, active: false)
        end

        schema '$ref' => '#/components/schemas/TagsResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['tags']).to eq(%w[GvG HA RA TA AB FA JQ PvP PvE])
        end
      end
    end
  end
end
