# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  config.openapi_root = Rails.root.join('docs/openapi').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  config.openapi_specs = {
    'teambuilds.yaml' => {
      openapi: '3.1.0',
      info: {
        title: 'GWRank Teambuilds API',
        version: '1.0.0',
        description: <<~DESC.squish
          The GWRank teambuild library API for Z-Codex. The payload is a .zcx document as normatively
          defined by docs/zcx_format.md (Z-Codex 1.2.0, version 18). Keys are strictly camelCase.
          Skill ids unknown to the catalog are preserved as-is (never normalized to zero).
        DESC
      },
      servers: [{ url: 'https://gwrank.com' }],
      security: [{ bearerAuth: [] }],
      paths: {},
      components: {
        securitySchemes: {
          bearerAuth: { type: :http, scheme: :bearer, bearerFormat: 'JWT', description: 'players.api_token' }
        },
        responses: {
          Unauthorized: { description: 'Missing or invalid token' },
          Forbidden: { description: "Someone else's private build, or unauthorized write" },
          BadRequest: {
            description: 'Malformed JSON or invalid identifier',
            content: {
              'application/json' => {
                schema: { '$ref': '#/components/schemas/ErrorList' }
              }
            }
          },
          Invalid: {
            description: 'Format rule violation (see docs/zcx_format.md §11)',
            content: {
              'application/json' => {
                schema: { '$ref': '#/components/schemas/ErrorList' }
              }
            }
          }
        },
        schemas: {
          Pagination: {
            type: :object,
            properties: {
              page: { type: :integer },
              perPage: { type: :integer },
              totalCount: { type: :integer }
            }
          },
          TagsResponse: {
            type: :object,
            required: ['tags'],
            properties: {
              tags: {
                type: :array,
                items: { type: :string },
                description: 'Closed list of tags accepted when publishing teambuilds, ordered by position'
              }
            }
          },
          RoomCreateResponse: {
            type: :object,
            required: %w[code creatorSecret websocketUrl expiresAt limits],
            properties: {
              code: { type: :string, pattern: '^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{3}$' },
              creatorSecret: { type: :string },
              websocketUrl: { type: :string, format: :uri },
              expiresAt: { type: :string, format: :'date-time' },
              limits: { '$ref': '#/components/schemas/RoomLimits' }
            }
          },
          RoomLimits: {
            type: :object,
            required: %w[participants payloadBytes messagesPerSecond],
            properties: {
              participants: { type: :integer, minimum: 1, maximum: 8 },
              payloadBytes: { type: :integer, minimum: 0, maximum: 16384 },
              messagesPerSecond: { type: :integer, minimum: 1, maximum: 10 }
            }
          },
          RoomError: {
            type: :object,
            required: ['errors'],
            properties: {
              errors: {
                type: :array,
                items: {
                  type: :object,
                  required: %w[code message],
                  properties: {
                    code: { type: :string, enum: ['rooms_full'] },
                    message: { type: :string }
                  }
                }
              }
            }
          },
          ErrorList: {
            type: :object,
            properties: {
              errors: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    path: { type: :string, examples: ['$.characters[0].skillIds'] },
                    code: {
                      type: :string,
                      enum: %w[malformed_json invalid_source_uuid invalid_updated_since not_an_object wrong_case null_array
                               duplicate_attribute_id invalid_skill_ids too_many_characters max_depth invalid_tag reserved_key precondition_failed]
                    },
                    message: { type: :string }
                  }
                }
              }
            }
          },
          TeambuildCharacterSummary: {
            type: :object,
            properties: {
              name: { type: :string },
              primaryProfession: { type: ['integer', 'null'], description: 'GW1 id 0-10' },
              secondaryProfession: { type: ['integer', 'null'] },
              eliteSkillId: { type: ['integer', 'null'], description: 'Official GW1 skill id' },
              assignment: { type: :string },
              dominantAttribute: { type: ['string', 'null'] }
            }
          },
          TeambuildSummary: {
            type: :object,
            properties: {
              id: { type: :integer },
              sourceId: { type: :string, format: :uuid },
              name: { type: :string },
              author: { type: :string, description: "Owner account name (@username without the @)" },
              tags: { type: :array, items: { type: :string } },
              gameMode: { type: :string },
              playerCount: { type: :integer },
              visibility: { type: :string, enum: %w[private public] },
              status: { type: :string, enum: %w[draft published] },
              characters: { type: :array, items: { '$ref': '#/components/schemas/TeambuildCharacterSummary' } },
              createdAt: { type: :string, format: :'date-time' },
              updatedAt: { type: :string, format: :'date-time' },
              documentHash: {
                type: :string,
                description: 'Hex SHA-256 of the canonicalized stored document (updatedAt excluded). Send it quoted as If-Match on PUT.'
              }
            }
          },
          TeambuildDeletion: {
            type: :object,
            description: 'Tombstone reported when a previously visible build was deleted (only with updated_since)',
            properties: {
              sourceId: { type: :string, format: :uuid },
              deletedAt: { type: :string, format: :'date-time' }
            }
          },
          UpsertResult: {
            allOf: [
              { '$ref': '#/components/schemas/TeambuildSummary' },
              {
                type: :object,
                properties: {
                  created: { type: :boolean },
                  changed: { type: :boolean }
                }
              }
            ]
          },
          TeambuildExport: {
            allOf: [
              { '$ref': '#/components/schemas/TeambuildSummary' },
              {
                type: :object,
                properties: {
                  document: { '$ref': '#/components/schemas/ZcxDocument' }
                }
              }
            ]
          },
          ZcxDocument: {
            type: :object,
            additionalProperties: true,
            description: <<~DESC.squish,
              The complete .zcx document — see docs/zcx_format.md as the normative reference.
              Known fields are typed below; any extra field is tolerated and preserved verbatim
              (future versions of the format).
            DESC
            properties: {
              version: { type: :integer, description: 'Informative, never routed' },
              id: { type: :string, format: :uuid },
              name: { type: :string },
              tags: {
                type: :array,
                maxItems: 24,
                items: { type: :string, maxLength: 64 },
                description: 'Closed list of nine canonical values (GvG HA RA TA AB FA JQ PvP PvE), case-insensitive: normalized on ingest and used by search filters. Unknown values are rejected with 422 invalid_tag; the authoritative list is served by GET /api/v1/tags.'
              },
              notes: { type: :string },
              createdAt: { type: :string, format: :'date-time' },
              updatedAt: { type: :string, format: :'date-time' },
              characters: {
                type: :array,
                maxItems: 12,
                items: { '$ref': '#/components/schemas/ZcxCharacter' }
              },
              locks: { type: :array, items: { type: :object, additionalProperties: true } },
              spike: { type: :array, items: { type: :object, additionalProperties: true } },
              flux: { type: :integer, minimum: 0, maximum: 12 },
              natureRituals: { type: :array, items: { type: :integer } },
              roaringWindsRank: { type: :integer, minimum: 0, maximum: 20 },
              tranquilityRank: { type: :integer, minimum: 0, maximum: 20 },
              gameMode: { type: :string, enum: ['All', 'PvE', 'PvP', ''] },
              vampiricHits3: { type: :integer, minimum: 0, maximum: 25 },
              vampiricHits5: { type: :integer, minimum: 0, maximum: 25 }
            }
          },
          ZcxCharacter: {
            type: :object,
            additionalProperties: true,
            properties: {
              id: { type: :string, format: :uuid },
              name: { type: :string },
              primaryProfession: { type: :integer, minimum: 0, maximum: 10 },
              secondaryProfession: { type: :integer, minimum: 0, maximum: 10 },
              isFavorite: { type: :boolean },
              assignment: { type: :string },
              gender: { type: :integer, enum: [0, 1] },
              skillIds: {
                type: :array,
                minItems: 8,
                maxItems: 8,
                items: { type: :integer },
                description: 'Slots 0-7; 0 = empty. Official GW1 ids, unknown ones tolerated.'
              },
              attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    points: { type: :integer }
                  },
                  required: %w[id points]
                },
                 description: "ids unique within a single character (otherwise rejected with 422)"
              },
              titleRanks: { type: :object, additionalProperties: { type: :integer } },
              equipment: { type: [:object, 'null'], additionalProperties: true },
              notes: { type: :string },
              durationBoostersEnabled: { type: :boolean },
              activeAttributeBoosts: { type: :array, items: { type: :integer } },
              variants: { type: :array, items: { '$ref': '#/components/schemas/ZcxCharacter' } }
            }
          }
        },
        examples: {
          GvgSplit: {
            summary: 'Single-character teambuild with variant/lock/spike (format §12)',
            value: {
              version: 18,
              id: '0f6a2f6c-9a1e-4b7d-9c3a-5f0e2b8c1d44',
              name: 'GvG Split',
              tags: ['GvG'],
              notes: '',
              createdAt: '2026-08-21T09:30:00Z',
              updatedAt: '2026-08-21T17:05:12Z',
              characters: [
                {
                  id: '11111111-1111-1111-1111-111111111111',
                  name: 'Water Snare',
                  primaryProfession: 6,
                  secondaryProfession: 5,
                  isFavorite: true,
                  assignment: 'Midline',
                  gender: 1,
                  skillIds: [1010, 1011, 0, 919, 2, 1064, 3, 1],
                  attributes: [
                    { id: 11, points: 12 },
                    { id: 12, points: 10 },
                    { id: 3, points: 8 }
                  ],
                  titleRanks: { 'Lightbringer rank': 8 },
                  equipment: {
                    armor: [{ slot: 2, itemId: 76, dye: 10, modifierIds: [129, 205] }],
                    weaponSets: [
                      {
                        items: [
                          { slot: 0, itemId: 21, dye: 0, modifierIds: [47] },
                          { slot: 1, itemId: 34, dye: 0, modifierIds: [] }
                        ]
                      }
                    ],
                    activeSet: 0
                  },
                  notes: 'Water elementalist & degeneration.',
                  durationBoostersEnabled: false,
                  activeAttributeBoosts: [],
                  variants: []
                }
              ],
              locks: [{ index: 1, color: '#FFD700', memberIds: ['11111111-1111-1111-1111-111111111111'] }],
              spike: [
                {
                  characterId: '11111111-1111-1111-1111-111111111111',
                  skills: [
                    {
                      slot: 0,
                      weaponDamageType: 'lightning',
                      ticks: 1,
                      order: 1,
                      weaponKind: nil,
                      procs: 1,
                      conditional: true,
                      threshold: -1,
                      casterCurrentHp: 480,
                      casterMaxHp: 480,
                      weaponMod: 'sundering',
                      sunderingProc: true,
                      hornbow: false
                    }
                  ],
                  buffs: ['judges-insight'],
                  slots: [],
                  weaponDamageType: nil
                }
              ],
              flux: 7,
              natureRituals: [1156],
              roaringWindsRank: 12,
              tranquilityRank: 12,
              gameMode: 'PvP',
              vampiricHits3: 1,
              vampiricHits5: 1
            }
          }
        }
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  config.openapi_format = :yaml
end
