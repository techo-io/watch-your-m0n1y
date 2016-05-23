## Watch Your M0n1y

Get instant notification of your payment history

获得你的金融一卡通消费记录和通知，并支持 Pushbullet 推送至移动设备

### Usage

1. Signup into [Pushbullet](https://www.pushbullet.com) and create API key
2. Configure your own `config.json`
3. Run `gem install` to install required gems
4. `ruby run.rb` or `chmod +x run.rb && ./run.rb`
5. Setup with this script with **crontab** or **daemonized** it, whatever you like
6. Checkout notifications on your devices

### Configuration

- 推送当日交易消费记录 Get today payment history `OPTIONS = { 'export_format': 'none', 'run_mode': RUN_MODE_DAEMON }`
- 获取某个日期之间的历史记录 Get the payment history from specific range of date  `OPTIONS = { 'export_format': 'csv', 'run_mode': RUN_MODE_HISTORY, 'start_date': 'YYYYMMDD', 'end_date': 'YYYYMMDD' }`

### Ref

- 校园卡查询系统 - http://172.31.7.16