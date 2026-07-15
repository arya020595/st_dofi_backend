class SequenceGenerator
  # column is always a code-controlled Symbol from the call site (e.g. :manifest_number), never
  # user input — quote_column_name still applied so this doesn't rely on that alone.
  def self.next_value(model:, column:, prefix:, digits: 3)
    quoted_column = model.connection.quote_column_name(column)
    next_num = model.where("#{quoted_column} LIKE ?", "#{prefix}%")
                    .maximum("CAST(SUBSTRING(#{quoted_column} FROM #{prefix.length + 1}) AS INTEGER)") || 0
    format("%<p>s%<n>0#{digits}d", p: prefix, n: next_num + 1)
  end
end
