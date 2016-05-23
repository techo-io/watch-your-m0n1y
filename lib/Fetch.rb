#!/usr/local/env ruby
require 'mechanize'
require 'net/http'

# options may contain
# - error_log_path: string
# - file_prefix: string
# - start_date: string, YYYYMMDD format
# - end_date: string, YYYYMMDD format
# - export_format: 'csv' | 'json' | 'none', 'csv' default by
# keys to perform custom actions

EXPORT_TYPE_CSV = 'csv'
EXPORT_TYPE_JSON = 'json'
EXPORT_TYPE_NONE = 'none'

class Fetch

  attr_accessor :username, :passwd, :options

  def initialize(username, passwd, options={})
    @username = username
    @passwd = passwd
    @options = options.inject({}){|memo,(k,v)| memo[k.to_s] = v; memo}
  end

  def send_login_request(username, passwd, cookie)
    # My API (POST )
    uri = URI('http://172.31.7.16/loginstudent.action')

    # Create client
    http = Net::HTTP.new(uri.host, uri.port)

    data = {
      "passwd" => passwd,
      "loginType" => "2",
      "rand" => "5410",
      "imageField.x" => "27",
      "userType" => "1",
      "imageField.y" => "10",
      "name" => username,
    }
    body = URI.encode_www_form(data)

    req =  Net::HTTP::Post.new(uri)
    req.add_field "Origin", "http://172.31.7.16"
    req.add_field "Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    req.add_field "Accept-Encoding", "gzip, deflate"
    req.add_field "Referer", "http://172.31.7.16/homeLogin.action"
    req.add_field "Cookie", cookie
    req.add_field "Content-Type", "application/x-www-form-urlencoded; charset=utf-8"
    req.add_field "Accept-Language", "en-us"
    req.body = body

    res = http.request(req)
    res
  end

  def do_login
    uri = URI('http://172.31.7.16/loginstudent.action')
    agent = Mechanize.new
    page = agent.get('http://172.31.7.16/homeLogin.action')
    agent.get('http://172.31.7.16/getCheckpic.action?rand=5410.66609788686')
    cookie = agent.cookies.first
    res = send_login_request(@username, @passwd, cookie.name + '=' + cookie.value)
    body = res.body
    page = agent.parse(uri, res, body)
    return page, agent
  end

  def run!
    page, agent = do_login
    # Check login successful

    date_str = Time.now.strftime("%Y%m%d")
    start_date = @options['start_date'] || date_str
    end_date = @options['end_date'] || date_str

    today_flag = start_date == date_str && end_date == date_str

    begin
      page = today_flag ? agent.get('http://172.31.7.16/accounttodayTrjn.action') : agent.get('http://172.31.7.16/accounthisTrjn.action')
    rescue StandardError => e
      err_msg = "Login failed for #{username} with debug info: (#{e.message})\n"
      puts err_msg
      if @options['error_log_path'] && File.writable?(@options['error_log_path'])
        File.open(@options['error_log_path'], 'a') do |f|
          f.flock(File::LOCK_EX)
          f.write(err_msg)
        end
      end
      return
    end
    form = page.form_with(:name => 'form1')
    page = agent.submit(form)

    if !today_flag
      form = page.form_with(:name => 'form1')
      form.field_with(:name => 'inputStartDate').value = start_date
      form.field_with(:name => 'inputEndDate').value = end_date
      page = agent.submit(form)
      form = page.form_with(:name => 'form1')
      page = agent.submit(form)
    end

    results = []

    export_type = EXPORT_TYPE_CSV
    if (@options['export_format'] && @options['export_format'].downcase === "json")
      export_type = EXPORT_TYPE_JSON
    elsif (@options['export_format'] && @options['export_format'].downcase === "none")
      export_type = EXPORT_TYPE_NONE
    end

    results << {
      :date => "交易发生时间",
      :stuid => "学号",
      :name => "姓名",
      :type => "交易类型",
      :loc => "子系统名称",
      :amount => "交易额",
      :deposit => "现有余额",
      :seq => "次数",
      :state => "状态",
    } if export_type == EXPORT_TYPE_CSV

    loop do
      # Final we get our data
      trs = page.xpath(today_flag ? '//form/table/tr/td/table[2]/tr[contains(@class, \'listbg\')]' : '//form/table/tr/td/table[2]/tr[2]/th/table/tr[contains(@class, \'listbg\')]')
      trs.each do |row|
        date = row.xpath('td[1]').first.text.strip
        stuid = row.xpath('td[2]').first.text.strip
        name = row.xpath('td[3]').first.text.strip
        type = row.xpath('td[4]').first.text.strip
        loc = row.xpath('td[5]').first.text.strip
        amount_str = row.xpath(today_flag ? 'td[7]' : 'td[6]').first.text.strip
        amount = amount_str.to_f
        deposit = row.xpath(today_flag ? 'td[8]' : 'td[7]').first.text.strip
        seq = row.xpath(today_flag ? 'td[9]' : 'td[8]').first.text.strip
        state = row.xpath(today_flag ? 'td[10]' : 'td[9]').first.text.strip
        results << {
          :date => date,
          :stuid => stuid,
          :name => name,
          :type => type,
          :loc => loc,
          :amount => amount,
          :deposit => deposit,
          :seq => seq,
          :state => state,
        }
      end

      hasNextPage = (page.link_with(:text => '下一页') != nil)
      break if !hasNextPage
      # puts 'Navigate to next page'
      form = page.form_with(:name => 'form1')
      form.action = 'http://172.31.7.16/accountconsubBrows.action'
      form.field_with(:name => 'pageNum').value = form.field_with(:name => 'pageNum').value.to_i + 1
      page = agent.submit(form)
    end

    filename = "#{(@options['file_prefix'] != "" && @options['file_prefix'] != nil) ? @options['file_prefix'] + "-" : ""}#{@username}_#{start_date}-#{end_date}."+export_type.to_s

    case export_type
    when EXPORT_TYPE_CSV
      results[1..-1] = results[1..-1].reverse
      str = results.map { |obj|
        obj[:date].to_s + ',' +
        obj[:stuid].to_s + ',' +
        obj[:name].to_s + ',' +
        obj[:type].to_s + ',' +
        obj[:loc].to_s + ',' +
        obj[:amount].to_s + ',' +
        obj[:deposit].to_s + ',' +
        obj[:seq].to_s + ',' +
        obj[:state].to_s
      }.join("\n")

      File.open(filename, 'w') do |f|
        f.write(str)
      end
    when EXPORT_TYPE_JSON
      File.open(filename, 'w') do |f|
        f.write(JSON.generate(results.reverse))
      end
    else
    end

    case export_type
    when EXPORT_TYPE_CSV
      results[1..-1]
    else
      results.reverse
    end
  end

end
