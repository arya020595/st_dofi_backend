module Realtime
  class CableToken
    TOKEN_TTL = 15.minutes

    class << self
      def issue(user)
        expires_at = TOKEN_TTL.from_now
        {
          realtime_token: verifier.generate({ user_id: user.id, jti: user.jti }, expires_at: expires_at),
          realtime_token_expires_at: expires_at.iso8601
        }
      end

      def user_for(token)
        payload = verifier.verified(token)
        return if payload.blank?

        User.kept.find_by(id: payload.fetch("user_id"), jti: payload.fetch("jti"))
      rescue ActiveSupport::MessageVerifier::InvalidSignature, KeyError
        nil
      end

      private

      def verifier
        @verifier ||= Rails.application.message_verifier("realtime_cable_token")
      end
    end
  end
end
