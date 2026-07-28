require "test_helper"

class PurgeUnattachedBlobsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "purges blobs unattached for more than 24 hours, leaves recent and attached ones alone" do
    stale = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("stale"), filename: "stale.png",
                                                   content_type: "image/png")
    stale.update!(created_at: 25.hours.ago)

    recent = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("recent"), filename: "recent.png",
                                                    content_type: "image/png")

    dictionary = create(:dictionary)
    dictionary.image.attach(io: StringIO.new("attached"), filename: "attached.png", content_type: "image/png")
    attached = dictionary.image.blob
    attached.update!(created_at: 25.hours.ago)

    perform_enqueued_jobs { PurgeUnattachedBlobsJob.perform_now }

    assert_nil ActiveStorage::Blob.find_by(id: stale.id)
    assert ActiveStorage::Blob.exists?(recent.id)
    assert ActiveStorage::Blob.exists?(attached.id)
  end
end
