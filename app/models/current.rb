class Current < ActiveSupport::CurrentAttributes
  attribute :request_id, :user_id, :brunei_id_token_response_keys, :brunei_id_token_metadata, :brunei_id_claims
end
