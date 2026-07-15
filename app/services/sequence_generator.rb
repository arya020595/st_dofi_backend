class SequenceGenerator
  def self.next_value(model:, column:, prefix:, digits: 3)
    next_num = model.where("#{column} LIKE ?", "#{prefix}%")
                    .maximum("CAST(SUBSTRING(#{column} FROM #{prefix.length + 1}) AS INTEGER)") || 0
    format("%<p>s%<n>0#{digits}d", p: prefix, n: next_num + 1)
  end
end
