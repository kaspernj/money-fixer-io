require "money"
require "open-uri"

class Money::Bank::FixerIo < Money::Bank::VariableExchange
  SERVICE_HOST = "api.fixer.io".freeze

  # @return [Hash] Stores the currently known rates.
  attr_reader :rates

  class << self
    # @return [Integer] Returns the Time To Live (TTL) in seconds.
    attr_reader :ttl_in_seconds

    # @return [Time] Returns the time when the rates expire.
    attr_reader :rates_expiration

    ##
    # Set the Time To Live (TTL) in seconds.
    #
    # @param [Integer] the seconds between an expiration and another.
    def ttl_in_seconds=(value)
      @ttl_in_seconds = value
      refresh_rates_expiration! if ttl_in_seconds
    end

    ##
    # Set the rates expiration TTL seconds from the current time.
    #
    # @return [Time] The next expiration.
    def refresh_rates_expiration!
      @rates_expiration = Time.now + ttl_in_seconds
    end
  end

  def initialize(*)
    super
  end

  def cache
    @@money_bank_fixer_io_cache ||= {}
  end

  ##
  # Clears all rates stored in @rates
  #
  # @return [Hash] The empty @rates Hash.
  #
  # @example
  #   @bank = GoogleCurrency.new  #=> <Money::Bank::GoogleCurrency...>
  #   @bank.get_rate(:USD, :EUR)  #=> 0.776337241
  #   @bank.flush_rates           #=> {}
  def flush_rates
    store.clear_rates
  end

  ##
  # Clears the specified rate stored in @rates.
  #
  # @param [String, Symbol, Currency] from Currency to convert from (used
  #   for key into @rates).
  # @param [String, Symbol, Currency] to Currency to convert to (used for
  #   key into @rates).
  #
  # @return [Float] The flushed rate.
  #
  # @example
  #   @bank = GoogleCurrency.new    #=> <Money::Bank::GoogleCurrency...>
  #   @bank.get_rate(:USD, :EUR)    #=> 0.776337241
  #   @bank.flush_rate(:USD, :EUR)  #=> 0.776337241
  def flush_rate(from, to)
    store.remove_rate(from, to)
  end

  ##
  # Returns the requested rate.
  #
  # It also flushes all the rates when and if they are expired.
  #
  # @param [String, Symbol, Currency] from Currency to convert from
  # @param [String, Symbol, Currency] to Currency to convert to
  #
  # @return [Float] The requested rate.
  #
  # @example
  #   @bank = GoogleCurrency.new  #=> <Money::Bank::GoogleCurrency...>
  #   @bank.get_rate(:USD, :EUR)  #=> 0.776337241
  def get_rate(from, to, args = {})
    expire_rates

    if args[:exchanged_at]
      exchanged_at = args.fetch(:exchanged_at).strftime("%Y-%m-%d")

      if cache[from] && cache[from][to] && cache[from][to][exchanged_at]
        cache[from][to][exchanged_at]
      else
        cache[from] ||= {}
        cache[from][to] ||= {}
        cache[from][to][exchanged_at] = fetch_rate(from, to, exchanged_at: exchanged_at)
      end
    else
      store.get_rate(from, to) || store.add_rate(from, to, fetch_rate(from, to))
    end
  end

  ##
  # Flushes all the rates if they are expired.
  #
  # @return [Boolean]
  def expire_rates
    if self.class.ttl_in_seconds && self.class.rates_expiration <= Time.now
      flush_rates
      self.class.refresh_rates_expiration!
      true
    else
      false
    end
  end

private

  ##
  # Queries for the requested rate and returns it.
  #
  # @param [String, Symbol, Currency] from Currency to convert from
  # @param [String, Symbol, Currency] to Currency to convert to
  #
  # @return [BigDecimal] The requested rate.
  def fetch_rate(from, to, args = {})
    from = Money::Currency.wrap(from)
    to = Money::Currency.wrap(to)
    uri = build_uri(from, to, args)

    data = JSON.parse(uri.read)
    rate = data.fetch("rates").fetch(to.iso_code)
    rate = 1 / extract_rate(build_uri(to, from).read) if rate < 0.1
    rate
  end

  ##
  # Build a URI for the given arguments.
  #
  # @param [Currency] from The currency to convert from.
  # @param [Currency] to The currency to convert to.
  #
  # @return [URI::HTTP]
  def build_uri(from, _to, args = {})
    if args[:exchanged_at]
      path = "/#{args.fetch(:exchanged_at)}"
    else
      path = "/latest"
    end

    query = "base=#{from.iso_code}"

    uri = URI::HTTP.build(
      host: SERVICE_HOST,
      path: path,
      query: query
    )
    uri
  end
end
