require 'net/http'
require 'telebot'
require 'rufus-scheduler' 
require 'logging'
require 'colorize'

path = '/home/flotbet/available/'
urls = File.foreach(path+'sites.ignore.txt').map { |line| line.gsub("\n",'' )}
TOKEN = File.open(path+'bot_token.ignore.txt').read
CHAT_ID = File.open(path+'chat_id.ignore.txt').read


LOGGER = Logging.logger['available']
LOGGER.level = :info

LOGGER.add_appenders \
Logging.appenders.stdout,
Logging.appenders.file(path+'available.log')

LOGGER.info "just some friendly advice"

scheduler = Rufus::Scheduler.new

# Отправка сообщеия через бот телеграме
# 
def send_message(message:)
	client = Telebot::Client.new(TOKEN) 
	client.send_message(chat_id: CHAT_ID, text: message )
rescue Exception => e
	error(e,__method__)
end

# Првоерка URL на доступность
# 
# @return [status: , code:] Статус и код возврата. CODE=access error если недоступен
def url_exist(url_string)
	url = URI.parse(url_string)
	req = Net::HTTP.new(url.host, url.port)
	req.use_ssl = (url.scheme == 'https')
	path = url.path unless url.path.empty?
	res = req.request_head(path || '/')
	if res.kind_of?(Net::HTTPRedirection)
		return url_exist(res['location']) 
	else
		return {status: true, code: res.code} if ! %W(4 5).include?(res.code[0]) 
		return {status: false, code: res.code} if %W(4 5).include?(res.code[0]) 
	end
rescue  
	return  {status: false, code: "access error"} 
end	

def error(e,method)
	LOGGER.error "[Main.#{method}]".on_red + ' error; ' + e.message
	e.backtrace.select { |x| LOGGER.error x.light_black.underline if x[/#{File.dirname(__FILE__)}/] }
end


# Проверка ссылок на доступность
# 
def check_urls(urls)
	urls.each do |url|
		result = url_exist(url)
		# send_message(message: "Result #{result}")
		LOGGER.info "url: #{url} + result: #{result}".green

		send_message(message: "Сайт #{url} недоступен. Код: #{result[:code]}") unless result[:status]
		sleep(1)
	end
rescue Exception => e
	error(e,__method__)
end


check_urls(urls)

scheduler.every '15m' do
	begin
		check_urls(urls)
	rescue Exception => e
		error(e,'15min')
	end
end





unless $0=='irb' || $0=='pry'
	scheduler.join
end



