module Manifests
  # Single source of truth for the denormalized master-data snapshots a manifest carries — see
  # docs/data-model/denormalized-snapshots.md. Both Create and Update need the exact same field
  # shape (once to set it, once to refresh/clear it), so it lives here rather than being defined
  # independently in each — a new snapshot field only needs to change in one place.
  class Snapshots
    def self.vessel(vessel)
      { companies_vessel: vessel, vessel_boat_name: vessel&.vessel_name, vessel_boat_no: vessel&.boat_number }
    end

    def self.captain(captain)
      { captain_crew: captain, captain_name: captain&.crew_name, captain_ic_number: captain&.ic_number }
    end

    def self.support_vessel(vessel)
      { support_vessel: vessel, support_vessel_name: vessel&.vessel_name, support_vessel_no: vessel&.boat_number }
    end

    def self.port_name(port_id)
      Port.find_by(id: port_id)&.port_name
    end
  end
end
