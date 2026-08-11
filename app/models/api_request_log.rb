class ApiRequestLog < LogRecord
  validates :body, presence: true
end

# == Schema Information
#
# Table name: api_request_logs
# Database name: logs
#
#  id         :uuid             not null, primary key
#  body       :jsonb            not null
#  created_at :datetime         not null
#
