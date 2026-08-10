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

ActiveRecord::Schema[8.1].define(version: 2026_08_10_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
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

  create_table "approval_remarks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_approval_remarks_on_discarded_at"
    t.index ["name"], name: "index_approval_remarks_on_name", unique: true
  end

  create_table "capture_reports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "capture_report_remarks"
    t.string "capture_report_status", default: "pending_verification", null: false
    t.datetime "created_at", null: false
    t.decimal "latitude", precision: 10, scale: 8
    t.decimal "longitude", precision: 11, scale: 8
    t.uuid "manifest_id", null: false
    t.datetime "reviewed_at"
    t.uuid "reviewed_by_id"
    t.datetime "updated_at", null: false
    t.string "zone_area"
    t.uuid "zone_id"
    t.index ["capture_report_status"], name: "index_capture_reports_on_capture_report_status"
    t.index ["manifest_id"], name: "index_capture_reports_on_manifest_id"
    t.index ["reviewed_by_id"], name: "index_capture_reports_on_reviewed_by_id"
    t.index ["zone_id"], name: "index_capture_reports_on_zone_id"
  end

  create_table "companies_crews", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "amendment_remarks"
    t.string "approval_status", default: "pending", null: false
    t.datetime "approved_at"
    t.uuid "approved_by_id"
    t.uuid "company_profile_id", null: false
    t.datetime "created_at", null: false
    t.string "crew_name", null: false
    t.date "date_of_birth"
    t.datetime "discarded_at"
    t.date "foreign_worker_license_end_date"
    t.string "foreign_worker_license_no"
    t.date "foreign_worker_license_start_date"
    t.string "gender"
    t.string "ic_number"
    t.string "nationality"
    t.string "passport_number"
    t.uuid "position_id"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["approval_status"], name: "index_companies_crews_on_approval_status"
    t.index ["approved_by_id"], name: "index_companies_crews_on_approved_by_id"
    t.index ["company_profile_id"], name: "index_companies_crews_on_company_profile_id"
    t.index ["discarded_at"], name: "index_companies_crews_on_discarded_at"
    t.index ["position_id"], name: "index_companies_crews_on_position_id"
    t.index ["status"], name: "index_companies_crews_on_status"
  end

  create_table "companies_documents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "amendment_remarks"
    t.string "approval_status", default: "pending", null: false
    t.datetime "approved_at"
    t.uuid "approved_by_id"
    t.uuid "company_profile_id", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "document_type", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_companies_documents_on_approved_by_id"
    t.index ["company_profile_id", "document_type"], name: "index_companies_documents_on_profile_and_type_kept", unique: true, where: "(discarded_at IS NULL)"
    t.index ["company_profile_id"], name: "index_companies_documents_on_company_profile_id"
    t.index ["discarded_at"], name: "index_companies_documents_on_discarded_at"
  end

  create_table "companies_fishing_gears", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "amendment_remarks"
    t.string "approval_status", default: "pending", null: false
    t.datetime "approved_at"
    t.uuid "approved_by_id"
    t.uuid "companies_vessel_id"
    t.uuid "company_profile_id", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.decimal "fishing_gear_fee", precision: 10, scale: 2
    t.uuid "fishing_gear_id", null: false
    t.string "fishing_gear_name"
    t.string "fishing_gear_type"
    t.string "local_name"
    t.integer "quantity"
    t.datetime "updated_at", null: false
    t.decimal "usage_value", precision: 10, scale: 2
    t.index ["approval_status"], name: "index_companies_fishing_gears_on_approval_status"
    t.index ["approved_by_id"], name: "index_companies_fishing_gears_on_approved_by_id"
    t.index ["companies_vessel_id"], name: "index_companies_fishing_gears_on_companies_vessel_id"
    t.index ["company_profile_id"], name: "index_companies_fishing_gears_on_company_profile_id"
    t.index ["discarded_at"], name: "index_companies_fishing_gears_on_discarded_at"
    t.index ["fishing_gear_id"], name: "index_companies_fishing_gears_on_fishing_gear_id"
  end

  create_table "companies_vessels", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "amendment_remarks"
    t.string "approval_status", default: "pending", null: false
    t.datetime "approved_at"
    t.uuid "approved_by_id"
    t.string "boat_number", null: false
    t.string "boat_type", default: "permanent", null: false
    t.integer "capacity"
    t.string "category"
    t.string "charter_type"
    t.uuid "company_profile_id", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.decimal "draft", precision: 10, scale: 2
    t.integer "engine_count"
    t.decimal "gross_tonnage", precision: 10, scale: 2
    t.decimal "horse_power", precision: 10, scale: 2
    t.boolean "is_powered", default: true, null: false
    t.decimal "length", precision: 10, scale: 2
    t.date "license_expiry_date"
    t.date "license_reg_date"
    t.string "material"
    t.integer "max_crew"
    t.string "registration_no"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.string "vessel_name", null: false
    t.integer "year_built"
    t.uuid "zone_id"
    t.index ["approval_status"], name: "index_companies_vessels_on_approval_status"
    t.index ["approved_by_id"], name: "index_companies_vessels_on_approved_by_id"
    t.index ["boat_number"], name: "index_companies_vessels_on_boat_number"
    t.index ["company_profile_id"], name: "index_companies_vessels_on_company_profile_id"
    t.index ["discarded_at"], name: "index_companies_vessels_on_discarded_at"
    t.index ["registration_no"], name: "index_companies_vessels_on_registration_no"
    t.index ["status"], name: "index_companies_vessels_on_status"
    t.index ["zone_id"], name: "index_companies_vessels_on_zone_id"
  end

  create_table "company_profile_contacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_profile_id", null: false
    t.datetime "created_at", null: false
    t.string "designation"
    t.datetime "discarded_at"
    t.string "full_name"
    t.string "gender"
    t.string "ic_colour"
    t.string "ic_no"
    t.datetime "updated_at", null: false
    t.index ["company_profile_id"], name: "index_company_profile_contacts_on_company_profile_id"
    t.index ["discarded_at"], name: "index_company_profile_contacts_on_discarded_at"
    t.index ["ic_no"], name: "index_company_profile_contacts_on_ic_no"
  end

  create_table "company_profiles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "amendment_remarks"
    t.string "approval_status", default: "pending", null: false
    t.datetime "approved_at"
    t.uuid "approved_by"
    t.text "company_address"
    t.string "company_name"
    t.string "contact_no"
    t.datetime "created_at", null: false
    t.date "date_approval"
    t.string "designation"
    t.datetime "discarded_at"
    t.string "district"
    t.string "dofi_registration_no"
    t.string "fisherman_card_no"
    t.string "full_address"
    t.string "full_name"
    t.string "gender"
    t.string "ic_colour"
    t.string "ic_no"
    t.date "issue_date"
    t.date "license_expiry_date"
    t.string "logo_url"
    t.string "mukim"
    t.string "registration_type", null: false
    t.string "rocbn_no"
    t.datetime "updated_at", null: false
    t.string "village"
    t.integer "worker_quota"
    t.index ["approval_status"], name: "index_company_profiles_on_approval_status"
    t.index ["approved_by"], name: "index_company_profiles_on_approved_by"
    t.index ["discarded_at"], name: "index_company_profiles_on_discarded_at"
    t.index ["ic_no"], name: "index_company_profiles_on_ic_no"
    t.index ["rocbn_no"], name: "index_company_profiles_on_rocbn_no"
  end

  create_table "crew_manifests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "companies_crew_id"
    t.datetime "created_at", null: false
    t.string "crew_name"
    t.date "date_of_birth"
    t.string "ic_number"
    t.uuid "manifest_id", null: false
    t.string "nationality"
    t.string "passport_number"
    t.string "position"
    t.datetime "updated_at", null: false
    t.index ["companies_crew_id"], name: "index_crew_manifests_on_companies_crew_id"
    t.index ["manifest_id"], name: "index_crew_manifests_on_manifest_id"
  end

  create_table "dictionaries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "family_name"
    t.string "group_name"
    t.string "local_name", null: false
    t.string "scientific_name"
    t.datetime "updated_at", null: false
    t.index ["local_name"], name: "idx_dictionaries_local_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["local_name"], name: "index_dictionaries_on_local_name"
    t.index ["scientific_name"], name: "idx_dictionaries_scientific_name_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "fish_capture_details", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "amount_captured_kg", precision: 10, scale: 3
    t.uuid "capture_report_id", null: false
    t.datetime "created_at", null: false
    t.uuid "dictionary_id", null: false
    t.string "fish_type"
    t.uuid "fishing_gear_detail_id"
    t.string "local_name"
    t.decimal "overall_total", precision: 12, scale: 2
    t.decimal "price_per_kg", precision: 10, scale: 2
    t.string "scientific_name"
    t.datetime "synced_at"
    t.datetime "updated_at", null: false
    t.index ["capture_report_id"], name: "index_fish_capture_details_on_capture_report_id"
    t.index ["dictionary_id"], name: "index_fish_capture_details_on_dictionary_id"
    t.index ["fishing_gear_detail_id"], name: "index_fish_capture_details_on_fishing_gear_detail_id"
  end

  create_table "fishing_gear_details", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "capture_report_id", null: false
    t.uuid "companies_fishing_gear_id"
    t.datetime "created_at", null: false
    t.string "gear_type"
    t.string "name"
    t.integer "quantity"
    t.string "specification"
    t.datetime "updated_at", null: false
    t.index ["capture_report_id"], name: "index_fishing_gear_details_on_capture_report_id"
    t.index ["companies_fishing_gear_id"], name: "index_fishing_gear_details_on_companies_fishing_gear_id"
  end

  create_table "fishing_gears", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "fee", precision: 10, scale: 2
    t.string "gear_specification"
    t.string "gear_type", null: false
    t.string "local_name"
    t.string "name", null: false
    t.decimal "size", precision: 10, scale: 2
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["gear_type"], name: "index_fishing_gears_on_gear_type"
    t.index ["name"], name: "index_fishing_gears_on_name"
  end

  create_table "manifest_expenses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "fuel_bnd", precision: 10, scale: 2
    t.decimal "fuel_litres", precision: 10, scale: 2
    t.decimal "ice_bnd", precision: 10, scale: 2
    t.decimal "ice_litres", precision: 10, scale: 2
    t.uuid "manifest_id", null: false
    t.decimal "ration_bnd", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.index ["manifest_id"], name: "index_manifest_expenses_on_manifest_id", unique: true
  end

  create_table "manifest_histories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.uuid "changed_by_id"
    t.datetime "created_at", null: false
    t.string "from_state"
    t.uuid "manifest_id", null: false
    t.jsonb "metadata", default: {}
    t.text "remarks"
    t.string "status_type"
    t.string "to_state"
    t.datetime "updated_at", null: false
    t.index ["changed_by_id"], name: "index_manifest_histories_on_changed_by_id"
    t.index ["manifest_id"], name: "index_manifest_histories_on_manifest_id"
  end

  create_table "manifest_minor_fishermen", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_of_birth", null: false
    t.string "full_name", null: false
    t.string "gender", null: false
    t.uuid "manifest_id", null: false
    t.string "relationship_with_owner", null: false
    t.datetime "updated_at", null: false
    t.index ["manifest_id"], name: "index_manifest_minor_fishermen_on_manifest_id"
  end

  create_table "manifest_skip_reasons", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_manifest_skip_reasons_on_discarded_at"
  end

  create_table "manifests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "ais_tracking", default: false, null: false
    t.uuid "captain_crew_id"
    t.string "captain_ic_number"
    t.string "captain_name"
    t.text "capture_report_amendment_remarks"
    t.boolean "capture_report_skipped", default: false, null: false
    t.uuid "companies_vessel_id", null: false
    t.string "company_name"
    t.uuid "company_profile_id", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id"
    t.datetime "discarded_at"
    t.string "fisherman_category", null: false
    t.boolean "has_minor_fishermen", default: false, null: false
    t.boolean "has_support_vessel", default: false, null: false
    t.decimal "latitude", precision: 10, scale: 8
    t.decimal "longitude", precision: 11, scale: 8
    t.string "manifest_number", null: false
    t.string "manifest_status", default: "draft", null: false
    t.text "port_in_amendment_remarks"
    t.string "port_in_area"
    t.datetime "port_in_datetime"
    t.uuid "port_in_id"
    t.string "port_in_name"
    t.string "port_in_status", default: "draft", null: false
    t.text "port_out_amendment_remarks"
    t.string "port_out_area"
    t.datetime "port_out_datetime"
    t.uuid "port_out_id"
    t.string "port_out_name"
    t.string "port_out_status", default: "draft", null: false
    t.uuid "skip_reason_id"
    t.string "skip_reason_name"
    t.text "skip_reason_remarks"
    t.uuid "support_vessel_id"
    t.string "support_vessel_name"
    t.string "support_vessel_no"
    t.datetime "updated_at", null: false
    t.string "vessel_boat_name"
    t.string "vessel_boat_no"
    t.string "zone_area"
    t.uuid "zone_id"
    t.index ["captain_crew_id"], name: "index_manifests_on_captain_crew_id"
    t.index ["capture_report_skipped"], name: "index_manifests_on_capture_report_skipped"
    t.index ["companies_vessel_id"], name: "index_manifests_on_companies_vessel_id"
    t.index ["company_profile_id"], name: "index_manifests_on_company_profile_id"
    t.index ["created_by_id"], name: "index_manifests_on_created_by_id"
    t.index ["discarded_at"], name: "index_manifests_on_discarded_at"
    t.index ["fisherman_category"], name: "index_manifests_on_fisherman_category"
    t.index ["manifest_number"], name: "index_manifests_on_manifest_number", unique: true
    t.index ["manifest_status"], name: "index_manifests_on_manifest_status"
    t.index ["port_in_id"], name: "index_manifests_on_port_in_id"
    t.index ["port_in_status"], name: "index_manifests_on_port_in_status"
    t.index ["port_out_id"], name: "index_manifests_on_port_out_id"
    t.index ["port_out_status"], name: "index_manifests_on_port_out_status"
    t.index ["skip_reason_id"], name: "index_manifests_on_skip_reason_id"
    t.index ["support_vessel_id"], name: "index_manifests_on_support_vessel_id"
    t.index ["zone_id"], name: "index_manifests_on_zone_id"
  end

  create_table "nationalities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_nationalities_on_code"
    t.index ["name"], name: "index_nationalities_on_name", unique: true
  end

  create_table "permission_roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "permission_id", null: false
    t.uuid "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_permission_roles_on_permission_id"
    t.index ["role_id", "permission_id"], name: "index_permission_roles_on_role_id_and_permission_id", unique: true
    t.index ["role_id"], name: "index_permission_roles_on_role_id"
  end

  create_table "permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_permissions_on_code", unique: true
  end

  create_table "ports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "latitude", precision: 10, scale: 8
    t.decimal "longitude", precision: 11, scale: 8
    t.string "port_name", null: false
    t.datetime "updated_at", null: false
    t.index ["port_name"], name: "index_ports_on_port_name"
  end

  create_table "positions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_positions_on_name", unique: true
  end

  create_table "roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "kind"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_roles_on_kind", unique: true
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "sequence_counters", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 0, null: false
    t.index ["key"], name: "index_sequence_counters_on_key", unique: true
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "brunei_id_verified_at"
    t.uuid "company_profile_contact_id"
    t.uuid "company_profile_id"
    t.string "contact_no"
    t.datetime "created_at", null: false
    t.string "designation"
    t.datetime "discarded_at"
    t.string "doft_registration_no"
    t.string "email", default: "", null: false
    t.string "employee_id"
    t.string "encrypted_password", default: "", null: false
    t.string "ic_number"
    t.string "jti", null: false
    t.string "name", null: false
    t.string "position"
    t.string "preferred_locale", default: "en", null: false
    t.string "registration_type"
    t.text "rejection_reason"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.uuid "role_id"
    t.string "status", default: "active", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["company_profile_contact_id"], name: "index_users_on_company_profile_contact_id"
    t.index ["company_profile_id"], name: "index_users_on_company_profile_id"
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["email"], name: "index_users_on_email", unique: true, where: "((email)::text <> ''::text)"
    t.index ["employee_id"], name: "index_users_on_employee_id", unique: true
    t.index ["ic_number"], name: "index_users_on_ic_number", unique: true, where: "(ic_number IS NOT NULL)"
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
    t.index ["username"], name: "index_users_on_username", unique: true
    t.check_constraint "preferred_locale::text = ANY (ARRAY['en'::character varying::text, 'ms'::character varying::text])", name: "check_users_preferred_locale"
  end

  create_table "zones", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "end_range"
    t.string "name", null: false
    t.string "start_range"
    t.datetime "updated_at", null: false
    t.string "zone_type"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "capture_reports", "manifests"
  add_foreign_key "capture_reports", "users", column: "reviewed_by_id"
  add_foreign_key "capture_reports", "zones"
  add_foreign_key "companies_crews", "company_profiles"
  add_foreign_key "companies_crews", "positions"
  add_foreign_key "companies_crews", "users", column: "approved_by_id"
  add_foreign_key "companies_documents", "company_profiles"
  add_foreign_key "companies_documents", "users", column: "approved_by_id"
  add_foreign_key "companies_fishing_gears", "companies_vessels"
  add_foreign_key "companies_fishing_gears", "company_profiles"
  add_foreign_key "companies_fishing_gears", "fishing_gears"
  add_foreign_key "companies_fishing_gears", "users", column: "approved_by_id"
  add_foreign_key "companies_vessels", "company_profiles"
  add_foreign_key "companies_vessels", "users", column: "approved_by_id"
  add_foreign_key "companies_vessels", "zones"
  add_foreign_key "company_profile_contacts", "company_profiles"
  add_foreign_key "company_profiles", "users", column: "approved_by"
  add_foreign_key "crew_manifests", "companies_crews"
  add_foreign_key "crew_manifests", "manifests"
  add_foreign_key "fish_capture_details", "capture_reports"
  add_foreign_key "fish_capture_details", "dictionaries"
  add_foreign_key "fish_capture_details", "fishing_gear_details"
  add_foreign_key "fishing_gear_details", "capture_reports"
  add_foreign_key "fishing_gear_details", "companies_fishing_gears"
  add_foreign_key "manifest_expenses", "manifests"
  add_foreign_key "manifest_histories", "manifests"
  add_foreign_key "manifest_histories", "users", column: "changed_by_id"
  add_foreign_key "manifest_minor_fishermen", "manifests"
  add_foreign_key "manifests", "companies_crews", column: "captain_crew_id"
  add_foreign_key "manifests", "companies_vessels"
  add_foreign_key "manifests", "companies_vessels", column: "support_vessel_id"
  add_foreign_key "manifests", "company_profiles"
  add_foreign_key "manifests", "manifest_skip_reasons", column: "skip_reason_id"
  add_foreign_key "manifests", "ports", column: "port_in_id"
  add_foreign_key "manifests", "ports", column: "port_out_id"
  add_foreign_key "manifests", "users", column: "created_by_id"
  add_foreign_key "manifests", "zones"
  add_foreign_key "permission_roles", "permissions"
  add_foreign_key "permission_roles", "roles"
  add_foreign_key "users", "company_profile_contacts"
  add_foreign_key "users", "company_profiles"
  add_foreign_key "users", "roles"
end
