require "spec_helper"

describe Money::Bank::FixerIo do
  let(:bank) { Money::Bank::FixerIo.new }
  let(:currency_eur) { Money::Currency.new("EUR") }
  let(:currency_dkk) { Money::Currency.new("DKK") }

  describe "#get_rate" do
    it "returns the right rates" do
      result = bank.get_rate(currency_eur, currency_dkk, exchanged_at: Time.new(2004, 1, 1))
      result = format("%.2f", result).to_f

      expect(result).to eq 7.39

      result = bank.get_rate(currency_eur, currency_dkk, exchanged_at: Time.new(2016, 1, 1))
      result = format("%.2f", result).to_f

      expect(result).to eq 7.46
    end

    it "does caching" do
      bank.get_rate(currency_eur, currency_dkk, exchanged_at: Time.new(2004, 1, 1))

      expect(bank.cache).to have_key currency_eur
      expect(bank.cache.fetch(currency_eur)).to have_key currency_dkk
      expect(bank.cache.fetch(currency_eur).fetch(currency_dkk)).to have_key "2004-01-01"

      result = bank.cache.fetch(currency_eur).fetch(currency_dkk).fetch("2004-01-01")
      result = format("%.2f", result).to_f

      expect(result).to eq 7.39
    end
  end
end
