require 'net/http'
require 'uri'
require 'json'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: pot_prices.rb [options]"

  opts.on("-v[X]", "--volume=X", "Show only pots with daily volume >= than X.") do |v|
    options[:volume] = v
  end
  opts.on("-m[0-1]", "--members=[0-1]", "0 (show only f2p), 1 (show only member)") do |v|
    options[:members] = v
  end
end.parse!

#gets the price of all the 3 dose and 4 dose potions in the past hour, and compares the price/dose for each of them for flipping potential.
#filters out any potions where either the 3 or 4 dose potion has 0 volume in the past hour

#the file to write the output to
file = File.new("prices.txt", "w")

#get the price data
url = URI.parse("https://prices.runescape.wiki/api/v1/osrs/1h")
#make a new get request and enable ssl
http = Net::HTTP.new(url.host, url.port)
http.use_ssl = (url.scheme == "https")

req = Net::HTTP::Get.new(url)
req['User-Agent'] = "testscript"
res = http.request(req)
data = JSON.parse(res.body)
data = data["data"]


#get the item data (to map price to name using id)
url = URI.parse("https://prices.runescape.wiki/api/v1/osrs/mapping")
http = Net::HTTP.new(url.host, url.port)
http.use_ssl = (url.scheme == "https")

req = Net::HTTP::Get.new(url)
req['User-Agent'] = "testscript"
res = http.request(req)
itemdata = JSON.parse(res.body)

final = {}

#get all the three dose potions
itemdata.each do |x|
  if x["name"].include?("\(3\)")
    #puts x["name"]
    name = x["name"].split('(')[0]
    dose = x["name"].split('(')[1].chomp(')').to_i
    id = x["id"].to_s
    #uses whichever of the high/low price has the highest volume
    if !data[id].nil?
      if data[id]["highPriceVolume"] >= data[id]["lowPriceVolume"]
        price = data[id]["avgHighPrice"]
        threevol = data[id]["highPriceVolume"]
      else
        price = data[id]["avgLowPrice"]
        threevol = data[id]["lowPriceVolume"]
      end
      price = price.to_i
    else
      price = 0
      threevol = 0
    end
    doseprice = price / dose
    #note: the item id is only for the 3 dose
    temp1 = {id: id, name: name, doseprice3: doseprice, doseprice4: 0, price3: price, price4: 0, diff: 0, vol3: threevol, vol4: 0, members: x["members"] == true ? 1 : 0}
    temp = {name => temp1}
    final.merge!(temp)
  end
end

#get 4 dose potions and match them with the 3 dose
itemdata.each do |x|
  if x["name"].include?("\(4\)")
    name = x["name"].split('(')[0]
    dose = x["name"].split('(')[1].chomp(')').to_i
    id = x["id"].to_s
    #uses whichever of the high/low price has the highest volume
    if !data[id].nil?
      if data[id]["highPriceVolume"] >= data[id]["lowPriceVolume"]
        price = data[id]["avgHighPrice"]
        fourvol = data[id]["highPriceVolume"]
      else
        price = data[id]["avgLowPrice"]
        fourvol = data[id]["lowPriceVolume"]
      end
      price = price.to_i
    else
      price = 0
      fourvol = 0
    end
    doseprice = price / dose
    if !final[name].nil?
      final[name][:doseprice4] = doseprice
      final[name][:price4] = price
      #takes any tax out of the diff now
      if price < 50 || name == 'Energy potion'
        final[name][:diff] = final[name][:doseprice4] - final[name][:doseprice3]
      else
        final[name][:diff] = (final[name][:doseprice4] - final[name][:doseprice3]) - ((final[name][:price4] * 0.02)/4).to_i
      end
      final[name][:vol4] = fourvol
    end
  end
end

#optional command line argument for minimum volume of 3 and 4 dose potions (0 by default)
min = 0
if !options[:volume].nil?
  min = options[:volume].to_i
end

is_members = -1
if !options[:members].nil?
  is_members = options[:members].to_i
end

#trim the outer names used to combine the data, remove any item where 3 or 4 dose volume is below the minimum volume (0 unless the user provided a command line arg), and then sort by profit
arr = final.flatten.reject { |ele| !ele.is_a?(Hash) }.reject { |ele| ele[:vol3] <= min }.reject { |ele| ele[:vol4] <= min }.sort_by { |h| -h[:diff] }

if is_members > -1
  arr = arr.reject { |ele| ele[:members] != is_members }
end

arr = arr.reject

#print the info to the file
file.print "#{'Name'.ljust(28)}|#{'Member'.ljust(6)}|#{' 3 Dose Price: '.ljust(16)}|#{' 4 Dose Price: '.ljust(16)}|#{' Price/Dose(3): '.ljust(16)}|#{' Price/Dose(4): '.ljust(16)}|#{' Profit/dose (w/tax): '.ljust(22)}|#{'3 Dose Volume: '.ljust(16)}|#{' 4 Dose Volume: '.ljust(16)}|\n"
arr.each do |n|
  file.print "#{n[:name].ljust(28)}|#{n[:members].to_s().ljust(6)}|#{n[:price3].to_s.ljust(16)}|#{n[:price4].to_s.ljust(16)}|#{n[:doseprice3].to_s.ljust(16)}|#{n[:doseprice4].to_s.ljust(16)}|#{n[:diff].to_s.ljust(22)}|#{n[:vol3].to_s.ljust(16)}|#{n[:vol4].to_s.ljust(16)}|\n"
  #file.print "#{n[:doseprice3]} #{n[:doseprice4]} #{n[:doseprice4] - n[:doseprice3]} #{n[:doseprice4] * 0.02}\n"
end

#file.puts(data)
#file.puts(itemdata)

file.close
