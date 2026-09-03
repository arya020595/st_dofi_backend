module Notifications
  class PublishToUsers
    def self.call(...) = new.call(...)

    def call(users:, attributes:, resource:)
      users.to_a.uniq.each do |user|
        CreateAndBroadcast.call(user:, attributes:, resource:)
      end
    end
  end
end
