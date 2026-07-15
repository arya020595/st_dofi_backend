class SequenceGenerator
  # Atomically issues the next number for a named, period-scoped counter (e.g. manifest_number
  # resets daily — the reset period is baked into `prefix`, so a new prefix naturally starts its
  # own counter at 1). Backed by one row per (key, prefix) in sequence_counters, incremented via a
  # Postgres upsert (INSERT ... ON CONFLICT DO UPDATE SET value = value + 1) — atomic at the
  # database level, so two callers racing for the same counter always get distinct, monotonically
  # increasing values; no read-then-write window exists for a race to land in.
  #
  # This replaced a MAX(...)+1 scan of manifest_number itself, which had two real defects:
  # concurrent callers could compute the same "next" number, causing a hard RecordNotUnique crash
  # against manifest_number's unique index, and deleting the highest-numbered record would cause
  # the next call to reissue an already-used number, since "next" was derived from what currently
  # exists rather than from what has ever been issued.
  #
  # dofi_registration_no and employee_id don't use this — they're opaque identifiers with no
  # human-meaning sequence, so a plain SecureRandom.uuid (unique by construction, no shared state)
  # is simpler and avoids sequence_counters contention entirely.
  def self.next_value(key:, prefix:, digits: 3)
    counter_key = "#{key}:#{prefix}"
    # rubocop:disable Rails/SkipsModelValidations -- the atomicity this whole class exists for
    # requires a single upsert statement; SequenceCounter's own validations only guard against
    # direct/manual writes bypassing this method, not this method's own reads/writes.
    result = SequenceCounter.upsert_all(
      [{ key: counter_key, value: 1 }],
      unique_by: :key,
      on_duplicate: Arel.sql("value = sequence_counters.value + 1, updated_at = now()"),
      returning: [:value]
    )
    # rubocop:enable Rails/SkipsModelValidations
    next_num = result.rows.first.first.to_i
    format("%<p>s%<n>0#{digits}d", p: prefix, n: next_num)
  end
end
