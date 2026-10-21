# rubocop:disable Rails/BulkChangeTable
class AddAmendmentSnapshotsToManifests < ActiveRecord::Migration[8.1]
  def change
    add_column :manifests, :port_out_amendment_remarks, :text
    add_column :manifests, :port_in_amendment_remarks, :text
    add_column :manifests, :capture_report_amendment_remarks, :text
  end
end
# rubocop:enable Rails/BulkChangeTable
