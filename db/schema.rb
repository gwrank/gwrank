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

ActiveRecord::Schema.define(version: 2021_04_25_113703) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "characters", force: :cascade do |t|
    t.bigint "player_id"
    t.string "igname"
    t.bigint "profession_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "is_archived", default: false
    t.index ["igname"], name: "index_characters_on_igname", unique: true
    t.index ["player_id"], name: "index_characters_on_player_id"
    t.index ["profession_id"], name: "index_characters_on_profession_id"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.text "body"
    t.integer "commentable_id"
    t.string "commentable_type"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["player_id"], name: "index_comments_on_player_id"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "guilds", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "slug"
    t.string "tag"
    t.integer "owner_id"
    t.string "region"
    t.boolean "is_archived", default: false
    t.index ["slug"], name: "index_guilds_on_slug", unique: true
  end

  create_table "matches", force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "tournament_id"
    t.integer "round"
    t.integer "number_on_round"
    t.integer "loser_team_id"
    t.integer "winner_team_id"
    t.integer "memorial_match_id"
    t.index ["tournament_id"], name: "index_matches_on_tournament_id"
  end

  create_table "pg_search_documents", force: :cascade do |t|
    t.text "content"
    t.string "searchable_type"
    t.bigint "searchable_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["searchable_type", "searchable_id"], name: "index_pg_search_documents_on_searchable"
  end

  create_table "players", force: :cascade do |t|
    t.string "email", default: ""
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "provider"
    t.string "uid"
    t.string "username"
    t.string "image_url"
    t.string "igname"
    t.boolean "is_warrior", default: false
    t.boolean "is_ranger", default: false
    t.boolean "is_monk", default: false
    t.boolean "is_necromancer", default: false
    t.boolean "is_mesmer", default: false
    t.boolean "is_elementalist", default: false
    t.boolean "is_assassin", default: false
    t.boolean "is_ritualist", default: false
    t.boolean "is_paragon", default: false
    t.boolean "is_dervish", default: false
    t.boolean "is_verified", default: false
    t.string "slug"
    t.string "twitch_username"
    t.bigint "guild_id"
    t.boolean "is_moderator", default: false
    t.boolean "is_admin", default: false
    t.index ["confirmation_token"], name: "index_players_on_confirmation_token", unique: true
    t.index ["email"], name: "index_players_on_email", unique: true
    t.index ["guild_id"], name: "index_players_on_guild_id"
    t.index ["reset_password_token"], name: "index_players_on_reset_password_token", unique: true
    t.index ["slug"], name: "index_players_on_slug", unique: true
    t.index ["unlock_token"], name: "index_players_on_unlock_token", unique: true
  end

  create_table "professions", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "profession_id"
  end

  create_table "registrations", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.datetime "registered_at"
    t.datetime "unregistered_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["player_id"], name: "index_registrations_on_player_id"
  end

  create_table "scrims", force: :cascade do |t|
    t.integer "team_a_id"
    t.integer "team_b_id"
    t.integer "captain_a_id"
    t.integer "captain_b_id"
    t.integer "winner_team_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "skills", force: :cascade do |t|
    t.integer "skill_id"
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "template_skill_id"
    t.string "skill_type"
    t.boolean "is_elite", default: false
    t.text "description"
    t.bigint "profession_id"
    t.index ["profession_id"], name: "index_skills_on_profession_id"
  end

  create_table "team_player_skills", force: :cascade do |t|
    t.bigint "team_player_id", null: false
    t.bigint "skill_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "position", default: 0
    t.index ["skill_id"], name: "index_team_player_skills_on_skill_id"
    t.index ["team_player_id"], name: "index_team_player_skills_on_team_player_id"
  end

  create_table "team_player_stats", force: :cascade do |t|
    t.bigint "team_player_id", null: false
    t.string "stat_key"
    t.integer "stat_value"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["team_player_id"], name: "index_team_player_stats_on_team_player_id"
  end

  create_table "team_players", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.bigint "player_id", null: false
    t.bigint "profession_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "is_captain", default: false
    t.string "igname"
    t.integer "secondary_profession_id"
    t.integer "position"
    t.bigint "character_id"
    t.index ["character_id"], name: "index_team_players_on_character_id"
    t.index ["player_id"], name: "index_team_players_on_player_id"
    t.index ["profession_id"], name: "index_team_players_on_profession_id"
    t.index ["team_id"], name: "index_team_players_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "match_id"
    t.bigint "guild_id"
    t.index ["guild_id"], name: "index_teams_on_guild_id"
    t.index ["match_id"], name: "index_teams_on_match_id"
  end

  create_table "tournament_results", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.integer "round", default: 0
    t.integer "position"
    t.integer "trim", default: 0
    t.bigint "guild_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["guild_id"], name: "index_tournament_results_on_guild_id"
    t.index ["round"], name: "index_tournament_results_on_round"
    t.index ["tournament_id"], name: "index_tournament_results_on_tournament_id"
  end

  create_table "tournaments", force: :cascade do |t|
    t.integer "year"
    t.integer "month"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "slug"
    t.date "date"
    t.string "map_rotation"
    t.integer "guild_number"
    t.string "tournament_type"
    t.index ["slug"], name: "index_tournaments_on_slug", unique: true
    t.index ["tournament_type"], name: "index_tournaments_on_tournament_type"
  end

  add_foreign_key "characters", "players"
  add_foreign_key "characters", "professions"
  add_foreign_key "comments", "players"
  add_foreign_key "matches", "tournaments"
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
