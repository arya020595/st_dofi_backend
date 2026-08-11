module ApiRequestLogs
  class Sanitizer
    class << self
      def filter(payload)
        normalized = normalize(payload)
        return if normalized.nil?

        parameter_filter.filter(normalized)
      end

      def masked_ic_number(ic_number)
        return if ic_number.blank?

        prefix = ic_number.to_s.split("-").first
        "#{prefix}-xxxxxx"
      end

      private

      def parameter_filter
        @parameter_filter ||= ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      end

      # rubocop:disable Metrics/MethodLength
      def normalize(payload)
        case payload
        when ActionController::Parameters
          payload.to_unsafe_h
        when Hash
          payload.deep_dup
        when Array
          payload.map { |item| normalize(item) }
        when nil, ""
          nil
        else
          payload
        end
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
