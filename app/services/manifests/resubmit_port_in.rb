module Manifests
  class ResubmitPortIn
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      return Failure(manifest) unless manifest.may_resubmit_port_in?

      manifest.resubmit_port_in!(actor: actor)
      Success(manifest)
    end
  end
end
