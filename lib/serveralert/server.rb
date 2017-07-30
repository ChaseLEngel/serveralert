require File.dirname(__FILE__) + '/database'

require 'net/ping/external'

class Server
  attr_reader :name, :ip, :ticket_id
  def initialize(name, ip)
    @name = name
    @ip = ip
    server = Database.instance.find(name, ip)
    if server.nil?
      server = Database.instance.insert(name, ip)
    end
    @ticket_id = server[4]
    @ping = Net::Ping::External.new @ip
  end

  def ping?
    @ping.ping?
  end

  def ticket_id=(ticket)
    @ticket_id = ticket
    Database.instance.ticket(@name, @ip, ticket)
  end

  def lock
    Database.instance.lock(@name, @ip)
  end

  def unlock
    Database.instance.unlock(@name, @ip)
  end

  def locked?
    Database.instance.locked?(@name, @ip)
  end
end
