module Manifests
  class ApprovePortIn
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      return Failure(manifest) unless manifest.may_approve_port_in?

      manifest.approve_port_in!(actor: actor)
      Success(manifest)
    end
  end
end
