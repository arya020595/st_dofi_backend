module Authentication
  # The one place that understands how a staff username is written.
  #
  # Local users.username is stored the way the Add User form produces it ("mprt/azri.nizam"), while a person may
  # type "Azri.Nizam", "MPRT/Azri.Nizam" or "MPRT\Azri.Nizam". The same class turns what was typed into the local
  # usernames it could mean, and turns a stored username into the short AD name (sAMAccountName) used for the bind,
  # so the identity sent to AD always comes from the matched row, never from raw input.
  class DirectoryUsername
    SHORT_NAME = /\A[a-z0-9._-]{1,64}\z/
    MAX_TYPED_LENGTH = 255

    def initialize(raw, domain:)
      @domain = domain.to_s.strip.downcase
      @typed = control_characters?(raw) ? "" : raw.to_s.strip.downcase
      @name = @domain.empty? ? @typed : @typed.sub(%r{\A#{Regexp.escape(@domain)}[\\/]}, "")
    end

    # The AD short name, or nil when the text is not a plausible one (another domain, odd characters, too long).
    def short = (@name if SHORT_NAME.match?(@name))

    # Local usernames this text can refer to, for a database lookup; empty for text no username can be.
    def stored_candidates
      return [] if @typed.empty? || @typed.length > MAX_TYPED_LENGTH

      [@typed, @name, (@domain.empty? ? nil : "#{@domain}/#{@name}")].compact_blank.uniq
    end

    private

    # String#strip would quietly drop a trailing NUL, so reject control characters before normalizing.
    def control_characters?(raw) = raw.to_s.match?(/[[:cntrl:]]/)
  end
end
