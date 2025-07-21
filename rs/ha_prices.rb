#!/usr/bin/ruby

require 'net/http'
require 'uri'
require 'json'
require 'optparse'

TICKS_PER_CAST = 5
TICKS_PER_MIN = 100
CASTS_PER_MIN = TICKS_PER_MIN / TICKS_PER_CAST

options = { firestaff: true }
OptionParser.new do |opts|
  opts.banner = 'Usage: ha_prices.rb [options]'

  opts.on('-vX', '--volume-min=X', 'Show only items with daily volume >= than X. Any limit by default.') do |v|
    options[:volume] = v
  end
  opts.on(
    '-pX',
    '--profit-min=X',
    'Show only items with a high alch. profit minimum of >= than X. 0 by default.'
  ) do |v|
    options[:min_profit] = v
  end
  opts.on('-m[0-1]', '--members=[0-1]', '0 (show only f2p), 1 (show only member)') do |v|
    options[:members] = v
  end
  opts.on('--no-fire-staff', 'Calculate profit assuming you\'re not wielding a fire staff. (e.g. using Bryo staff)') do
    options[:firestaff] = false
  end
end.parse!

# optional command line argument for minimum volume (0 by default)
min_volume = 0
# optional command line argument for minimum HA profit (0 by default)
min_profit = 0
# optional cli argument for filtering by members/non-members, default is -1 (no filter)
is_members = -1

min_volume = options[:volume].to_i unless options[:volume].nil?
min_profit = options[:min_profit].to_i unless options[:min_profit].nil?
is_members = options[:members].to_i unless options[:members].nil?

# the file to write the output to
file = File.new('ha_items.md', 'w')

# get the price data
url = URI.parse('https://prices.runescape.wiki/api/v1/osrs/1h')
# make a new get request and enable ssl
http = Net::HTTP.new(url.host, url.port)
http.use_ssl = (url.scheme == 'https')

req = Net::HTTP::Get.new(url)
req['User-Agent'] = 'high-alch-calculator'
res = http.request(req)
data = JSON.parse(res.body)
data = data['data']

# get the item data (to map price to name using id)
url = URI.parse('https://prices.runescape.wiki/api/v1/osrs/mapping')
http = Net::HTTP.new(url.host, url.port)
http.use_ssl = (url.scheme == 'https')

req = Net::HTTP::Get.new(url)
req['User-Agent'] = 'high-alch-calculator'
res = http.request(req)
itemdata = JSON.parse(res.body)

final = {}

nr_high_price = data[itemdata.find { |ele| ele['name'] == 'Nature rune' }['id'].to_s]['avgHighPrice']
fr_high_price = data[itemdata.find { |ele| ele['name'] == 'Fire rune' }['id'].to_s]['avgHighPrice']
nr_low_price = data[itemdata.find { |ele| ele['name'] == 'Nature rune' }['id'].to_s]['avgLowPrice']
fr_low_price = data[itemdata.find { |ele| ele['name'] == 'Fire rune' }['id'].to_s]['avgLowPrice']

nr_price = (nr_high_price + nr_low_price) / 2
fr_price = options[:firestaff] ? 0 : (fr_high_price + fr_low_price) / 2
ha_rune_cost = nr_price + (5 * fr_price)

# get all items
longest = 0
itemdata.each do |x|
  next if x['highalch'].nil?
  next if x['limit'].nil?

  name = x['name']
  longest = name.length > longest ? name.length : longest
  id = x['id'].to_s
  buy_limit = x['limit'].nil? ? 0 : x['limit']
  # uses whichever of the high/low price has the highest volume
  price = 0
  unless data[id].nil?
    if data[id]['highPriceVolume'] >= data[id]['lowPriceVolume']
      price = data[id]['avgHighPrice']
      vol = data[id]['highPriceVolume']
    else
      price = data[id]['avgLowPrice']
      vol = data[id]['lowPriceVolume']
    end
    price = price.to_i
  end
  next if vol.nil?

  profit = x['highalch'] - (price + ha_rune_cost)
  temp1 = {
    id: id,
    name: name,
    price: price,
    vol: vol,
    high_alch_value: x['highalch'],
    profit_per_unit: profit,
    profit_per_min: profit * (buy_limit >= CASTS_PER_MIN ? CASTS_PER_MIN : buy_limit),
    profit_per_hour: profit * (buy_limit >= CASTS_PER_MIN * 60 ? CASTS_PER_MIN * 60 : buy_limit),
    profit_at_limit: profit * (buy_limit >= CASTS_PER_MIN * 60 * 4 ? CASTS_PER_MIN * 60 * 4 : buy_limit),
    buy_limit: buy_limit,
    members: x['members'] == true ? 1 : 0
  }
  temp = { name => temp1 }
  final.merge!(temp)
end

# trim the outer names used to combine the data, remove items where volume is below the minimum volume (70 unless the user provided a command line arg), and then sort by profit
arr =
  final
  .flatten
  .select { |ele| ele.is_a?(Hash) }
  .reject { |ele| ele[:vol] <= min_volume }
  .reject { |ele| ele[:profit_per_unit] <= 0 || ele[:profit_per_unit] < min_profit }
  .select { |ele| is_members == -1 || ele[:members] == is_members }
  .sort_by { |h| -h[:profit_at_limit] }

# select all items with profit >= min_profit

# print the info to the file
file.print "# High Alch Prices \n"
file.print "  - Prices calculated assuming firestaff is #{options[:firestaff] ? 'equipped' : 'not equipped'}.\n"
file.print "  - HA Rune Cost: #{ha_rune_cost.to_s.ljust(6)}\n"
file.print "  - Maximum possible burn rate of #{CASTS_PER_MIN * 60 * 4} items every 4 hours. \n\n"
file.print "\n"
file.print "|#{'Item Name'.center(longest)}|#{'Membrs'.center(8)}|#{'Price'.center(15)}|#{'HA Value'.center(15)}"
file.print "|#{'Buy Limit/4HR'.center(15)}|#{'Profit/Item'.center(15)}|#{'Profit/Hr'.center(15)}"
file.print "|#{'Profit/4Hr'.center(15)}|#{'Daily Volume'.center(15)}|\n"
file.print "|#{'---'.center(longest)}|#{'---'.center(8)}|#{'---'.center(15)}|#{'---'.center(15)}"
file.print "|#{'---'.center(15)}|#{'---'.center(15)}|#{'---'.center(15)}|#{'---'.center(15)}|#{'---'.center(15)}|\n"
arr.each do |n|
  file.print "|#{n[:name].ljust(longest)}|#{n[:members].to_s.rjust(8)}|#{n[:price].to_s.rjust(15)}|"
  file.print "#{n[:high_alch_value].to_s.rjust(15)}|#{n[:buy_limit].to_s.rjust(15)}|#{n[:profit_per_unit].to_s.rjust(15)}|"
  file.print "#{n[:profit_per_hour].to_s.rjust(15)}|#{n[:profit_at_limit].to_s.rjust(15)}|#{n[:vol].to_s.rjust(15)}|\n"
end

# file.puts(data)
# file.puts(itemdata)
