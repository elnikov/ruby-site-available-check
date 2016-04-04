require 'net/http'
require 'telebot'
require 'rufus-scheduler' 

urls = File.foreach('sites.ignore.txt').map { |line| line.gsub("\n",'' )}
TOKEN = File.open('bot_token.ignore.txt').read
CHAT_ID = File.open('chat_id.ignore.txt').read


scheduler = Rufus::Scheduler.new

# Отправка сообщеия через бот телеграме
# 
def send_message(message:)
	client = Telebot::Client.new(TOKEN) 
	# client.send_message(chat_id: '64342023', text: message )
	client.send_message(chat_id: CHAT_ID, text: message )
rescue 

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

# Проверка ссылок на доступность
# 
def check_urls(urls)
	urls.each do |url|
		result = url_exist(url)
		p result
		send_message(message: "Сайт #{url} недоступен. Код: #{result[:code]}") unless result[:status]
		sleep(1)
	end
end


check_urls(urls)

scheduler.every '15m' do
	check_urls(urls)
end



unless $0=='irb' || $0=='pry'
	scheduler.join
end



