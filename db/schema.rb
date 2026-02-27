# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_27_145347) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "alliances", force: :cascade do |t|
    t.string "allegiance_rank"
    t.datetime "created_at", null: false
    t.integer "faction"
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", null: false
  end

  create_table "characters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "igname"
    t.boolean "is_archived", default: false
    t.bigint "player_id"
    t.bigint "profession_id"
    t.datetime "updated_at", null: false
    t.index ["igname"], name: "index_characters_on_igname", unique: true
    t.index ["player_id"], name: "index_characters_on_player_id"
    t.index ["profession_id"], name: "index_characters_on_profession_id"
  end

  create_table "comments", force: :cascade do |t|
    t.text "body"
    t.integer "commentable_id"
    t.string "commentable_type"
    t.datetime "created_at", null: false
    t.bigint "player_id", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_comments_on_player_id"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "scope"
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "guilds", force: :cascade do |t|
    t.bigint "alliance_id"
    t.text "announcement"
    t.integer "bronze_trims_count", default: 0
    t.string "cape_trim"
    t.datetime "created_at", null: false
    t.string "faction"
    t.integer "gold_trims_count", default: 0
    t.string "guild_hall"
    t.boolean "is_archived", default: false
    t.bigint "leader_id"
    t.string "members_count"
    t.string "name"
    t.integer "owner_id"
    t.string "region"
    t.integer "silver_trims_count", default: 0
    t.string "slug"
    t.string "tag"
    t.string "territory"
    t.datetime "updated_at", null: false
    t.string "voip"
    t.string "voip_url"
    t.index ["alliance_id"], name: "index_guilds_on_alliance_id"
    t.index ["leader_id"], name: "index_guilds_on_leader_id"
    t.index ["slug"], name: "index_guilds_on_slug", unique: true
  end

  create_table "items", force: :cascade do |t|
    t.string "campaign"
    t.string "canonical_title"
    t.string "categories", default: [], array: true
    t.string "common_salvage"
    t.datetime "created_at", null: false
    t.jsonb "image", default: {}
    t.jsonb "notes", default: {}
    t.string "parts", default: [], array: true
    t.string "rare_salvage"
    t.string "rarity"
    t.jsonb "raw_infobox", default: {}
    t.jsonb "rolls", default: {}
    t.string "slug"
    t.string "source_url"
    t.jsonb "stats", default: {}
    t.string "subtype"
    t.string "title"
    t.string "type"
    t.datetime "updated_at", null: false
    t.integer "value"
    t.string "weapon_range"
    t.string "weapon_type"
  end

  create_table "matches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "exported_at"
    t.datetime "imported_at"
    t.bigint "imported_by_id"
    t.jsonb "json", default: {}
    t.integer "loser_team_id"
    t.integer "memorial_match_id"
    t.string "name"
    t.integer "number_on_round"
    t.datetime "played_at"
    t.integer "round"
    t.string "slug"
    t.bigint "tournament_id"
    t.datetime "updated_at", null: false
    t.integer "winner_team_id"
    t.index ["imported_by_id"], name: "index_matches_on_imported_by_id"
    t.index ["tournament_id"], name: "index_matches_on_tournament_id"
  end

  create_table "movies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "movieable_id"
    t.string "movieable_type"
    t.bigint "player_id", null: false
    t.string "provider"
    t.datetime "updated_at", null: false
    t.string "video_url"
    t.index ["player_id"], name: "index_movies_on_player_id"
  end

  create_table "pg_search_documents", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.bigint "searchable_id"
    t.string "searchable_type"
    t.datetime "updated_at", null: false
    t.index ["searchable_type", "searchable_id"], name: "index_pg_search_documents_on_searchable"
  end

  create_table "players", force: :cascade do |t|
    t.string "api_token"
    t.datetime "confirmation_sent_at", precision: nil
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "email", default: ""
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.bigint "guild_id"
    t.string "igname"
    t.string "image_url"
    t.boolean "is_admin", default: false
    t.boolean "is_assassin", default: false
    t.boolean "is_dervish", default: false
    t.boolean "is_elementalist", default: false
    t.boolean "is_mesmer", default: false
    t.boolean "is_moderator", default: false
    t.boolean "is_monk", default: false
    t.boolean "is_necromancer", default: false
    t.boolean "is_paragon", default: false
    t.boolean "is_ranger", default: false
    t.boolean "is_ritualist", default: false
    t.boolean "is_verified", default: false
    t.boolean "is_warrior", default: false
    t.datetime "last_sign_in_at", precision: nil
    t.string "last_sign_in_ip"
    t.datetime "locked_at", precision: nil
    t.string "provider"
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "slug"
    t.string "twitch_username"
    t.string "uid"
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["confirmation_token"], name: "index_players_on_confirmation_token", unique: true
    t.index ["email"], name: "index_players_on_email", unique: true
    t.index ["guild_id"], name: "index_players_on_guild_id"
    t.index ["reset_password_token"], name: "index_players_on_reset_password_token", unique: true
    t.index ["slug"], name: "index_players_on_slug", unique: true
    t.index ["unlock_token"], name: "index_players_on_unlock_token", unique: true
  end

  create_table "professions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "profession_id"
    t.string "short_name"
    t.datetime "updated_at", null: false
  end

  create_table "registrations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "player_id", null: false
    t.datetime "registered_at", precision: nil
    t.datetime "unregistered_at", precision: nil
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_registrations_on_player_id"
  end

  create_table "scrims", force: :cascade do |t|
    t.integer "captain_a_id"
    t.integer "captain_b_id"
    t.datetime "created_at", null: false
    t.integer "team_a_id"
    t.integer "team_b_id"
    t.datetime "updated_at", null: false
    t.integer "winner_team_id"
  end

  create_table "skills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "is_elite", default: false
    t.string "name"
    t.bigint "profession_id"
    t.integer "skill_id"
    t.string "skill_type"
    t.integer "template_skill_id"
    t.datetime "updated_at", null: false
    t.index ["profession_id"], name: "index_skills_on_profession_id"
  end

  create_table "team_player_skills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position", default: 0
    t.bigint "skill_id", null: false
    t.bigint "team_player_id", null: false
    t.datetime "updated_at", null: false
    t.index ["skill_id"], name: "index_team_player_skills_on_skill_id"
    t.index ["team_player_id"], name: "index_team_player_skills_on_team_player_id"
  end

  create_table "team_player_stats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "stat_key"
    t.integer "stat_value"
    t.bigint "team_player_id", null: false
    t.datetime "updated_at", null: false
    t.index ["team_player_id"], name: "index_team_player_stats_on_team_player_id"
  end

  create_table "team_players", force: :cascade do |t|
    t.bigint "character_id"
    t.datetime "created_at", null: false
    t.string "igname"
    t.boolean "is_captain", default: false
    t.bigint "player_id", null: false
    t.integer "position"
    t.bigint "profession_id"
    t.integer "secondary_profession_id"
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["character_id"], name: "index_team_players_on_character_id"
    t.index ["player_id"], name: "index_team_players_on_player_id"
    t.index ["profession_id"], name: "index_team_players_on_profession_id"
    t.index ["team_id"], name: "index_team_players_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "guild_id"
    t.bigint "match_id"
    t.integer "rank"
    t.integer "rating"
    t.datetime "updated_at", null: false
    t.index ["guild_id"], name: "index_teams_on_guild_id"
    t.index ["match_id"], name: "index_teams_on_match_id"
  end

  create_table "tournament_results", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "guild_id", null: false
    t.integer "position"
    t.integer "round", default: 0
    t.bigint "tournament_id", null: false
    t.integer "trim", default: 0
    t.datetime "updated_at", null: false
    t.index ["guild_id"], name: "index_tournament_results_on_guild_id"
    t.index ["round"], name: "index_tournament_results_on_round"
    t.index ["tournament_id"], name: "index_tournament_results_on_tournament_id"
  end

  create_table "tournaments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date"
    t.integer "guild_number"
    t.string "map_rotation"
    t.integer "month"
    t.string "region"
    t.string "slug"
    t.string "tournament_type"
    t.datetime "updated_at", null: false
    t.integer "year"
    t.index ["slug"], name: "index_tournaments_on_slug", unique: true
    t.index ["tournament_type"], name: "index_tournaments_on_tournament_type"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "characters", "players"
  add_foreign_key "characters", "professions"
  add_foreign_key "comments", "players"
  add_foreign_key "guilds", "alliances"
  add_foreign_key "guilds", "players", column: "leader_id"
  add_foreign_key "matches", "players", column: "imported_by_id"
  add_foreign_key "matches", "tournaments"
  add_foreign_key "movies", "players"
  add_foreign_key "players", "guilds"
  add_foreign_key "registrations", "players"
  add_foreign_key "skills", "professions"
  add_foreign_key "team_player_skills", "skills"
  add_foreign_key "team_player_skills", "team_players"
  add_foreign_key "team_player_stats", "team_players"
  add_foreign_key "team_players", "characters"
  add_foreign_key "team_players", "players"
  add_foreign_key "team_players", "professions"
  add_foreign_key "team_players", "teams"
  add_foreign_key "teams", "guilds"
  add_foreign_key "teams", "matches"
  add_foreign_key "tournament_results", "guilds"
  add_foreign_key "tournament_results", "tournaments"
end
