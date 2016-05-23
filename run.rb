#!/usr/local/env ruby
require_relative 'lib/Fetch.rb'
require 'open-uri'
require 'json'
require 'washbullet'

# config.json must contain
# - pushbullet_api_key: string
# - stuid: string
# - password: string
# keys to run this script

RUN_MODE_DAEMON = 'daemon'
RUN_MODE_HISTORY = 'history'

OPTIONS = { 'export_format': 'none', 'run_mode': RUN_MODE_DAEMON }

config = JSON.parse(open('config.json').read, :symbolize_names => true)

date_str = Time.now.strftime("%Y%m%d")

fetcher = Fetch.new(config[:stuid], config[:password], OPTIONS.merge({'start_date': date_str, 'end_date': date_str}))
results = fetcher.run!

if !OPTIONS['run_mode'] || OPTIONS['run_mode'] == RUN_MODE_DAEMON
  store_path = date_str + '.dat'
  `echo {} > #{store_path}` if !File.exist?store_path
  last_results = JSON.parse(open(store_path).read, :symbolize_names => true)
  diff = results.reject{ |x| last_results.include?x }
  has_diff = !diff.empty?
  if has_diff
    client = Washbullet::Client.new(config[:pushbullet_api_key])
    client.devices.each do |device|
      client.push_note(
        receiver:   :device,
        identifier: device.identifier,
        params: {
          title: config[:stuid] + ' 校园卡余额有变动',
          body: JSON.pretty_generate(diff)
        }
      )
    end
    File.open(store_path, 'w') do |f|
      f.write(JSON.generate(results))
    end
  end
end
