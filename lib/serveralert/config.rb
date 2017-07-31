require 'json'

class Config
  NoConfigFile = Class.new(StandardError)
  NoSettings = Class.new(StandardError)
  NoServers = Class.new(StandardError)
  MissingKey = Class.new(StandardError)

  class Settings < Config
    class Email < Config
      attr_reader :smtp, :port, :domain, :from, :password, :to
      ATTRIBUTES = ['smtp', 'port', 'domain', 'from', 'password', 'to']
      def initialize(email_hash)
        validateHash(email_hash, ATTRIBUTES)
        @smtp = email_hash['smtp']
        @port = email_hash['port']
        @domain = email_hash['domain']
        @from = email_hash['from']
        @password = email_hash['password']
        @to = email_hash['to']
      end
    end

    class HelpDesk < Config
      attr_reader :assignee_email, :email, :password
      ATTRIBUTES = ['assignee_email', 'email', 'password']
      def initialize(help_desk_hash)
        validateHash(help_desk_hash, ATTRIBUTES)
        @assignee_email = help_desk_hash['assignee_email']
        @email = help_desk_hash['email']
        @password = help_desk_hash['password']
      end
    end

    class Ping < Config
      attr_reader :count, :wait
      ATTRIBUTES = ['count', 'wait']
      def initialize(ping_hash)
        validateHash(ping_hash, ATTRIBUTES)
        @count = ping_hash['count']
        @wait = ping_hash['wait']
      end
    end

    attr_reader :interval, :help_desk, :email, :ping
    ATTRIBUTES = ['interval', 'help_desk', 'email', 'ping']
    def initialize(settings_hash)
      validateHash(settings_hash, ATTRIBUTES)
      @interval = settings_hash['interval'] + 'm'
      @help_desk = HelpDesk.new settings_hash['help_desk']
      @email = Email.new settings_hash['email']
      @ping = Ping.new settings_hash['ping']
    end
  end

  class Servers < Config
    attr_reader :servers
    ATTRIBUTES = ['name', 'ip']
    def initialize(servers_array)
      @servers = []
      servers_array.each do |server|
        validateHash(server, ATTRIBUTES)
        @servers << Server.new(server['name'], server['ip'])
      end
    end

    class Server
      attr_reader :name, :ip
      def initialize(name, ip)
        @name = name
        @ip = ip
      end
    end
  end

  attr_reader :settings
  ATTRIBUTES = ['settings', 'servers']
  def initialize(file)
    unless File.exist? file
      fail NoConfigFile, "#{file} does not exist or is not a file."
    end
    @config = JSON.parse File.read(file)
    validateHash(@config, ATTRIBUTES)
    @settings = Settings.new(@config['settings'])
    @servers = Servers.new(@config['servers'])
  end

  def servers
    @servers.servers
  end

  protected
  def validateHash(hash, keys)
    keys.each do |key|
      unless hash.has_key?(key)
        fail MissingKey, "Config is missing key #{key}."
      end
    end
  end
end

