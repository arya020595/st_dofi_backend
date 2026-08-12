class Current < ActiveSupport::CurrentAttributes
  attribute :request_id, :user_id, :brunei_id_token_response_keys, :brunei_id_token_metadata, :brunei_id_claims,
            :brunei_id_token_response, :brunei_id_userinfo
end
