require 'net/http'
require 'telebot'
require 'rufus-scheduler' 
require 'logging'
require 'colorize'
require 'byebug'
require 'rubygems'
require 'dnsruby'
include Dnsruby




# # Load DLV key
# dlv_key = Dnsruby::RR.create("dlv.isc.org. IN DNSKEY 257 3 5 BEAAAAPHMu/5onzrEE7z1egmhg/WPO0+juoZrW3euWEn4MxDCE1+lLy2 brhQv5rN32RKtMzX6Mj70jdzeND4XknW58dnJNPCxn8+jAGl2FZLK8t+ 1uq4W+nnA3qO2+DL+k6BD4mewMLbIYFwe0PG73Te9fZ2kJb56dhgMde5 ymX4BI/oQ+cAK50/xvJv00Frf8kw6ucMTwFlgPe+jnGxPPEmHAte/URk Y62ZfkLoBAADLHQ9IrS2tryAe7mbBZVcOwIeU/Rw/mRx/vwwMCTgNboM QKtUdvNXDrYJDSHZws3xiRXF1Rf+al9UmZfSav/4NWLKjHzpT59k/VSt TDN0YUuWrBNh")
# Dnsruby::Dnssec.add_dlv_key(dlv_key)

# resolver = Dnsruby::Recursor.new

# resolver.recursion_callback = Proc.new do |packet|
#     packet.additional.each { |a| puts a }
#     LOGGER.info(";; Received #{packet.answersize} bytes from #{packet.answerfrom}. Security Level = #{packet.security_level.string}\n".red)
#     LOGGER.info("\n#{'-' * 79}\n".red)
#     send_message((";; Received #{packet.answersize} bytes from #{packet.answerfrom}. Security Level = #{packet.security_level.string}\n")
# end




path = '/home/flotbet/available/'
urls = File.foreach(path+'sites.ignore.txt').map { |line| line.gsub("\n",'' )}
TOKEN = File.open(path+'bot_token.ignore.txt').read
CHAT_ID = File.open(path+'chat_id.ignore.txt').read


LOGGER = Logging.logger['available']
LOGGER.level = :info

LOGGER.add_appenders \
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
        return {status: true, code: res.code, inspect: res.inspect(), value: res.value} if ! %W(4 5).include?(res.code[0]) 
        if %W(4 5).include?(res.code[0]) 
            return {status: false, code: res.code, inspect: res.inspect(), value: res.value} 
        end
    end
rescue  
    return  {status: false, code: "access error", inspect: res.inspect()} 
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
        # res = Dnsruby::Resolver.new
        # dns = res.query(url.sub(/^https?\:\/\//, '').sub(/^www./,''))
        # send_message(message: "Result #{result}")
        # 
        
        if result[:status]
            LOGGER.info "url: #{url}  Result: #{result}".green
            # LOGGER.info "url: #{url}  DNS: #{dns.answer.inspect()}".green
        else
            send_message(message: "Сайт #{url} недоступен. Код: #{result[:code]}}") 
            LOGGER.info "url: #{url}  Result: #{result}".red
            # LOGGER.info "url: #{url}  Result: #{result}".red
            # response = resolver.query(url.sub(/^https?\:\/\//, '').sub(/^www./,'', CNAME)
            # LOGGER.info "url: #{url}  DNS: #{dns.answer.inspect()}".red
        end
        sleep(1)
    end
rescue Exception => e
    error(e,__method__)
end


check_urls(urls)

scheduler.every '5s' do
    begin
        check_urls(urls)
    rescue Exception => e
        error(e,'15min')
    end
end






unless $0=='irb' || $0=='pry'
    scheduler.join
end



