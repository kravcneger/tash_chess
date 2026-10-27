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

ActiveRecord::Schema[8.1].define(version: 2026_10_27_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "games", force: :cascade do |t|
    t.bigint "round_id", null: false
    t.integer "board", null: false
    t.bigint "white_player_id", null: false
    t.bigint "black_player_id"
    t.string "result", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["black_player_id"], name: "index_games_on_black_player_id"
    t.index ["round_id", "board"], name: "index_games_on_round_id_and_board", unique: true
    t.index ["white_player_id"], name: "index_games_on_white_player_id"
    t.check_constraint "(black_player_id IS NULL) = (result::text = 'bye'::text)", name: "games_bye_has_no_opponent"
    t.check_constraint "board > 0", name: "games_board_positive"
    t.check_constraint "result::text = ANY (ARRAY['pending'::character varying::text, 'white_won'::character varying::text, 'black_won'::character varying::text, 'draw'::character varying::text, 'bye'::character varying::text])", name: "games_result_valid"
    t.check_constraint "white_player_id <> black_player_id", name: "games_distinct_players"
  end

  create_table "participations", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.bigint "player_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "withdrawn_at"
    t.string "access_token", null: false
    t.index ["access_token"], name: "index_participations_on_access_token", unique: true
    t.index ["player_id"], name: "index_participations_on_player_id"
    t.index ["tournament_id", "player_id"], name: "index_participations_on_tournament_id_and_player_id", unique: true
  end

  create_table "players", force: :cascade do |t|
    t.string "name", null: false
    t.string "nickname", null: false
    t.integer "fide_rating"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((nickname)::text)", name: "index_players_on_lower_nickname", unique: true
    t.check_constraint "fide_rating >= 1000 AND fide_rating <= 3000", name: "players_fide_rating_range"
  end

  create_table "rounds", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.integer "number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tournament_id", "number"], name: "index_rounds_on_tournament_id_and_number", unique: true
  end

  create_table "tournaments", force: :cascade do |t|
    t.string "name", null: false
    t.string "location"
    t.date "starts_on"
    t.string "pairing_system", default: "swiss", null: false
    t.integer "rounds_count"
    t.string "status", default: "registration", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_tournaments_on_status"
    t.check_constraint "pairing_system::text = ANY (ARRAY['swiss'::character varying::text, 'round_robin'::character varying::text])", name: "tournaments_pairing_system_valid"
    t.check_constraint "rounds_count IS NULL OR rounds_count > 0", name: "tournaments_rounds_count_positive"
    t.check_constraint "status::text = ANY (ARRAY['registration'::character varying::text, 'in_progress'::character varying::text, 'finished'::character varying::text])", name: "tournaments_status_valid"
  end

  add_foreign_key "games", "players", column: "black_player_id"
  add_foreign_key "games", "players", column: "white_player_id"
  add_foreign_key "games", "rounds", on_delete: :cascade
  add_foreign_key "participations", "players"
  add_foreign_key "participations", "tournaments", on_delete: :cascade
  add_foreign_key "rounds", "tournaments", on_delete: :cascade
end
