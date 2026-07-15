module Manifests
  class ResubmitPortOut
    include Dry::Monads[:result]

    def self.call(...) = new.call(...)

    def call(manifest, actor:)
      return Failure(manifest) unless manifest.may_resubmit_port_out?

      manifest.resubmit_port_out!(actor: actor)
      Success(manifest)
    end
  end
end
