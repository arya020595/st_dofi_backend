FactoryBot.define do
  factory :manifest_history do
    manifest
    action { "submit_port_out" }
    status_type { "port_out_status" }
    from_state { "draft" }
    to_state { "pending" }
  end
end
