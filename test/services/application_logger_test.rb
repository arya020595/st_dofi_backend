require "test_helper"

class ApplicationLoggerTest < ActiveSupport::TestCase
  setup do
    @output = StringIO.new
    @logger = Logger.new(@output)
    @logger.formatter = ->(_severity, _time, _progname, message) { "#{message}\n" }
    @service = ApplicationLogger.new(logger: @logger, clock: -> { Time.utc(2026, 10, 6, 12) })
  end

  teardown { Current.reset }

  test "every level uses the same schema and request context" do
    Current.request_id = "request-1"
    ApplicationLogger::LEVELS.each do |level|
      @service.call(event: "example.completed", level:, user_id: "user-1", params: { count: 2 })
    end

    assert_equal(ApplicationLogger::LEVELS.map do |level|
      { "timestamp" => "2026-10-06T12:00:00.000Z", "level" => level.to_s, "event" => "example.completed",
        "request_id" => "request-1", "user_id" => "user-1", "params" => { "count" => 2 } }
    end, @output.string.lines.map { |line| JSON.parse(line) })
  end

  test "nested secrets and personal data are filtered without mutating caller parameters" do
    params = { client_secret: "secret", people: [{ icnumber: "01-123456", full_name: "Private Name" }],
               response: { access_token: "token", headers: { authorization: "Bearer token" }, body: "raw" },
               audience: "fisherman" }
    original = Marshal.load(Marshal.dump(params))
    @service.call(event: "example.completed", params:)

    filtered = { "client_secret" => "[FILTERED]",
                 "people" => [{ "icnumber" => "[FILTERED]", "full_name" => "[FILTERED]" }],
                 "response" => { "access_token" => "[FILTERED]", "headers" => "[FILTERED]", "body" => "[FILTERED]" },
                 "audience" => "fisherman" }

    assert_equal [filtered, original],
                 [JSON.parse(@output.string).fetch("params"), params]
  end

  test "logger threshold skips formatting and output" do
    @logger.level = Logger::WARN
    service = ApplicationLogger.new(logger: @logger, clock: -> { flunk "Suppressed logs must not be formatted" })
    service.call(event: "example.completed", level: :debug)

    assert_empty @output.string
  end

  test "invalid levels event names and parameter types are rejected" do
    [{ level: :trace }, { level: nil }, { event: nil }, { event: "Contains arbitrary text" },
     { params: "raw payload" }].each do |arguments|
      assert_raises(ArgumentError) { @service.call(event: "example.completed", **arguments) }
    end
  end

  test "log output IO failures do not fail the business operation" do
    writer = Object.new
    def writer.info = raise(IOError, "unavailable output")

    assert_not ApplicationLogger.new(logger: writer).call(event: "example.completed")
  end
end
