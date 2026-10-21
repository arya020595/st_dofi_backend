require "test_helper"
require "prism"

class LifecycleStatusWritesTest < ActiveSupport::TestCase
  class StatusWriteVisitor < Prism::Visitor
    STATUS_COLUMNS = %w[manifest_status port_out_status port_in_status capture_report_status].freeze
    HASH_WRITERS = %i[new build create create! update update! update_all update_columns assign_attributes].freeze
    ATTRIBUTE_WRITERS = %i[update_column write_attribute []=].freeze

    attr_reader :lines

    def initialize
      super
      @lines = []
    end

    def visit_call_node(node)
      @lines << node.location.start_line if direct_write?(node)
      super
    end

    private

    def direct_write?(node)
      return true if status_setter?(node.name)

      arguments = node.arguments&.arguments.to_a
      return status_key?(arguments.first) if ATTRIBUTE_WRITERS.include?(node.name)

      HASH_WRITERS.include?(node.name) && arguments.any? { |argument| status_hash?(argument) }
    end

    def status_setter?(name)
      name = name.to_s
      name.end_with?("=") && STATUS_COLUMNS.include?(name.delete_suffix("="))
    end

    def status_hash?(node)
      return false unless node.is_a?(Prism::HashNode) || node.is_a?(Prism::KeywordHashNode)

      node.elements.any? { |element| element.is_a?(Prism::AssocNode) && status_key?(element.key) }
    end

    def status_key?(node)
      (node.is_a?(Prism::SymbolNode) || node.is_a?(Prism::StringNode)) && STATUS_COLUMNS.include?(node.unescaped)
    end
  end

  test "application code never writes lifecycle status columns directly" do
    offenders = Rails.root.glob("app/**/*.rb").flat_map do |file|
      direct_write_lines(file.read).map { |line| "#{file.relative_path_from(Rails.root)}:#{line}" }
    end

    assert_empty offenders, "Use literal AASM events inside lifecycle services:\n#{offenders.join("\n")}"
  end

  test "guard detects multiline writes and setters but allows read predicates" do
    source = <<~RUBY_CODE
      report.update!(
        capture_report_status: "verified"
      )
      manifest.manifest_status = "completed"
      scope.where(port_in_status: "pending")
      report.update_column(:capture_report_status, "verified")
    RUBY_CODE

    assert_equal [1, 4, 6], direct_write_lines(source)
  end

  private

  def direct_write_lines(source)
    visitor = StatusWriteVisitor.new
    visitor.visit(Prism.parse(source).value)
    visitor.lines
  end
end
