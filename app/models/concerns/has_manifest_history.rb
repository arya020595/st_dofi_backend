module HasManifestHistory
  extend ActiveSupport::Concern

  # includer must implement #manifest_id_for_history
  # aasm_name defaults to :default (AASM's own default machine name) rather than nil — passing nil
  # explicitly to #aasm does NOT fall back to its `name=:default` parameter default, since Ruby only
  # applies a method's default value when the argument is omitted, not when nil is passed.
  def record_history!(status_type, aasm_name: :default, actor: nil, remarks: nil, metadata: {})
    machine = aasm(aasm_name)
    ManifestHistory.create!(manifest_id: manifest_id_for_history, action: machine.current_event.to_s,
                            status_type: status_type, from_state: machine.from_state.to_s,
                            to_state: machine.to_state.to_s, changed_by_id: actor&.id,
                            remarks: remarks, metadata: metadata)
  end
end
