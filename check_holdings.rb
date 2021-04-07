# frozen_string_literal: true

require 'evergreen_holdings'
require 'marc'
require 'nokogiri'
require 'open-uri'
require 'stringio'
require 'thor'

# A CLI for checking a file of OCLC numbers against Evergreen to see if we maintain holdings
# of them
class CheckHoldings < Thor
  desc 'check URL PATH_TO_OCLC_NUMBER_FILE', 'Get a list of OCLC numbers you should delete'
  def check(url, path_to_oclc_number_file)
    conn = EvergreenHoldings::Connection.new url

    File.readlines(path_to_oclc_number_file).each do |oclc_number|
      response = Nokogiri::XML(URI.parse(
        "#{url}/opac/extras/sru?operation=searchRetrieve&query=dc.identifier=#{oclc_number.strip}"
      ).open)
      records = response.xpath('//marc:record', 'marc' => 'http://www.loc.gov/MARC21/slim')
      marc = MARC::XMLReader.new(StringIO.new(records.to_s))

      next unless marc

      matching_records = marc.find_all { |record| record['035']['a'].delete('^0-9') == oclc_number.strip }
      if matching_records.any?
        identifier = matching_records.first['001'].value
        status = conn.get_holdings identifier
        valid_copy = status.copies.find do |item|
          item.location == 'Stacks'
        end
        puts oclc_number unless valid_copy # We hold a copy, but wouldn't ILL it.  Report it as eligible for deletion
      else
        puts oclc_number # We don't hold any copies.  Report it as eligible for deletion
      end

      sleep 2
    end
  end
end

CheckHoldings.start(ARGV)
