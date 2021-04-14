# frozen_string_literal: true

require 'dotenv/load'
require 'evergreen_holdings'
require 'marc'
require 'nokogiri'
require 'open-uri'
require 'stringio'
require 'thor'

GOOD_ITEM_STATUSES = [
  'Available',
  'Checked out',
  'In transit',
  'On holds shelf',
  'Reshelving'
].freeze

# A CLI for checking a file of OCLC numbers against Evergreen to see if we maintain holdings
# of them
class CheckHoldings < Thor

  def initialize(*args)
    @conn = EvergreenHoldings::Connection.new ENV['EVERGREEN_URL']
    super
  end

  desc 'deletes PATH_TO_OCLC_NUMBER_FILE', 'Get a list of OCLC numbers you should delete'
  def deletes(path_to_oclc_number_file)

    File.readlines(path_to_oclc_number_file).each do |oclc_number|
      next if normalize(oclc_number).empty?

      begin
        response = Nokogiri::XML(URI.parse(
          "#{ENV['EVERGREEN_URL']}/opac/extras/sru?operation=searchRetrieve&query=dc.identifier=#{normalize(oclc_number)}"
        ).open)
      rescue Errno::ECONNRESET, Errno::ETIMEDOUT
        next
      end
      records = response.xpath('//marc:record', 'marc' => 'http://www.loc.gov/MARC21/slim')
      marc = MARC::XMLReader.new(StringIO.new(records.to_s))

      next unless marc

      matching_records = marc.find_all { |record| extract_oclc_number_from_marc(record) == normalize(oclc_number) }
      if matching_records.any?
        eg_db_id = matching_records.first['001'].value
        unless any_items_loanable?(eg_db_id)
          puts oclc_number # We hold a copy, but wouldn't ILL it.  Report it as eligible for deletion
        end
      else
        puts oclc_number # We don't hold any copies.  Report it as eligible for deletion
      end

      sleep 2
    end
  end

  desc 'adds [PATH_TO_EG_DB_ID_FILE]',
       'Get a list of OCLC numbers you should add. If no file given, pull the latest 200 records from supercat'
  def adds(path_to_eg_db_id_file=nil)

    if path_to_eg_db_id_file
      File.readlines(path_to_eg_db_id_file).each do |eg_db_id|
        next if normalize(eg_db_id).empty?
        next unless any_items_loanable?(eg_db_id)

        records = fetch_and_marcify("#{ENV['EVERGREEN_URL']}/opac/extras/supercat/retrieve/marcxml/record/#{normalize(eg_db_id)}")
        puts extract_oclc_number_from_marc records.first
        sleep 1
      end
    else
      fetch_and_marcify("#{ENV['EVERGREEN_URL']}/opac/extras/feed/freshmeat/marcxml/biblio/edit/200").each do |record|
        next unless any_items_loanable?(record['001'].value)

        puts extract_oclc_number_from_marc record # There are some valid items!
      end
    end
  end

  private

  def any_items_loanable?(eg_db_id)
    status = @conn.get_holdings normalize(eg_db_id)
    status.copies.any? do |item|
      item.location == 'Stacks' &&
        (GOOD_ITEM_STATUSES.include? item.status) &&
        item.circ_modifier == 'DEFAULT'
    end
  end

  def extract_oclc_number_from_marc(record)
    return nil unless record['035']

    # Check to make sure that we get an 035 field with ocm, ocn, or (OCoLC)
    oclc_field = record.detect { |field| field.tag == '035' && /oc/i.match(field['a']) }
    oclc_field ? normalize(oclc_field['a']) : nil
  end

  def normalize(identifier)
    identifier.delete('^0-9')
  end

  def fetch_and_marcify(url)
    xml = URI.parse(url).open
    MARC::XMLReader.new(xml)
  end

end

CheckHoldings.start(ARGV)
