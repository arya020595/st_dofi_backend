class AddPositionIdToCompaniesCrews < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_reference :companies_crews, :position, type: :uuid, index: { algorithm: :concurrently }

    # Best-effort name match against master data; existing free-text values (e.g. "Deckhand") predate
    # the Crew-category Position rows and won't match, so most rows stay position_id: nil until
    # re-profiled through the app — acceptable pre-launch, position_id is nullable at the DB level.
    safety_assured do
      execute <<~SQL.squish
        UPDATE companies_crews
        SET position_id = positions.id
        FROM positions
        WHERE positions.name = companies_crews.position
      SQL
    end
  end

  def down
    remove_reference :companies_crews, :position, index: { algorithm: :concurrently }
  end
end
