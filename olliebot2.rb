require '../ruby-irc/irc-connection.rb'
require 'rubygems'

class Olliebot2
  attr_accessor :nick
  attr_reader :connection, :plugins

  def initialize(nick="Olliebot", username="olliebot", realname="Olliebot", host=nil, port=nil, password=nil)
    @host = host
    @port = port
    @password = password
    @nick = nick
    @username = username
    @realname = realname
    
    @connection = IRCConnection.new @nick, @username, @realname, @password
    
    load_plugins
    
    handle_all_events
    
    if host and port then
      @connection.connect host, port
    end
  end
  
  def connect(host, port=6667)
    @host = host
    @port = port
    
    @connection.connect host, port
  end
  
  def disconnect
    @connection.quit
  end
  
  def reload_plugins
    load_plugins(true)
  end
  
  #private
  
  def load_plugins(reload=false)
    @plugins = {}
    Dir.glob 'plugins/*.plugin.rb' do |filename|
      begin
        filename =~ /plugins\/(.+?)\.plugin\.rb/
        module_name = $1
        if reload then
          Object.send(:remove_const, module_name.to_sym)
        end
        load filename
        module_ref = Object.const_get module_name
        priority = module_ref.const_get "Priority"
        if !@plugins[priority] then
          @plugins[priority] = []
        end
        @plugins[priority] << module_ref.const_get("Plugin").new(self)
      rescue => exception
        $stderr.puts "Failed to load " + filename
        $stderr.puts exception.inspect
      end
    end
    @plugins
  end
  
  # All events are handled by a single method
  def handle_all_events
    @connection.set_generic_handler do |event|
      begin
        handle_event(event)
      rescue => exception
        $stderr.puts exception.inspect
        $stderr.puts exception.backtrace
      end
    end
    true
  end
  
  def handle_event(event)
    #$stderr.puts event.command + ' ' + event.params.join(' ')
    method = ("handle_" + event.command).to_sym
    @plugins.keys.reverse.each do |priority|
      @plugins[priority].each do |plugin|
        if plugin.respond_to? method then
          plugin.send(method, event)
        end
      end
    end
    true
  end
end