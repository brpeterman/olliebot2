# Olliebot2
# The bot itself has basically not functionality. All functionality is handled
# in plugins. See https://github.com/brpeterman/olliebot2-plugins for examples.
# 
# To use:
# Create a new Olliebot2 instance and call #connect.
# Plugins may be updated while the bot is running. If you make a modification
# or add a new plugin, just call #reload_plugins.

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
    @plugins = []
    Dir.glob 'plugins/*.plugin.rb' do |filename|
      begin
        filename =~ /plugins\/(.+?)\.plugin\.rb/
        module_name = $1
        if reload then
          begin
            module_ref = Object.const_get module_name
            module_ref.constants(false).each do |const|
              module_ref.send(:remove_const, const)
            end
            Object.send(:remove_const, module_name)
          rescue NameError
          end
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
    method = ("handle_" + event.command).to_sym
    # Call plugins by highest priority to lowest
    @plugins.reverse.each do |priority|
      if priority then
        priority.each do |plugin|
          if plugin.respond_to? method then
            plugin.send(method, event)
          end
        end
      end
    end
    true
  end
end