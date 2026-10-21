# The position category "Crew" is gone: the roster positions (Boat Captain, Full-Time Fisherman, ...) now live
# under "Fisherman" like everything else on that platform, and CompaniesCrew validates against it. Deploys run
# db:prepare only (no seed), so rows that already carry the old category have to be moved here.
#
# The seeded generic "Crew" position (category "Fisherman") is dropped too — it is not a real roster role, and
# under the merged category it would show up in the crew position picker. Only deleted while nothing
# references it.
class MergeCrewPositionCategoryIntoFisherman < ActiveRecord::Migration[8.1]
  ROSTER_POSITIONS = ["Boat Captain", "Full-Time Fisherman", "Part-Time Fisherman", "Ice & Storage Assistant",
                      "Logistic Assistant"].freeze

  def up
    safety_assured do
      execute <<~SQL.squish
        DELETE FROM positions
        WHERE name = 'Crew' AND category = 'Fisherman'
          AND id NOT IN (SELECT position_id FROM companies_crews WHERE position_id IS NOT NULL)
      SQL
      execute "UPDATE positions SET category = 'Fisherman' WHERE category = 'Crew'"
    end
  end

  # Restores the category on the known roster positions only; the deleted generic "Crew" row is not recreated.
  def down
    safety_assured do
      names = ROSTER_POSITIONS.map { |name| connection.quote(name) }.join(", ")
      execute "UPDATE positions SET category = 'Crew' WHERE name IN (#{names})"
    end
  end
end
