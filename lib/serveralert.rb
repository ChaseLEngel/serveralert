require 'json'
require 'rufus-scheduler'

require File.dirname(__FILE__) + '/serveralert/locker'
require File.dirname(__FILE__) + '/serveralert/helpdeskapi'
require File.dirname(__FILE__) + '/serveralert/mailer'
require File.dirname(__FILE__) + '/serveralert/logger'
require File.dirname(__FILE__) + '/serveralert/config'
require File.dirname(__FILE__) + '/serveralert/worker'

# Parse config.json
config_path = File.dirname(__FILE__) + '/../config.json'
config = JSON.parse(File.read(config_path))
settings = config['settings']
# Credentials for Spiceworks Help Desk
help_desk = settings['help_desk']
# How often in minutes workers will run.
# m denotes minutes
interval = settings['interval'] + "m"
# Settings and credentials for email
email = settings['email']

locker_path = File.dirname(__FILE__) + '/../servers.lock'
locker = Locker.new(locker_path)

# Start logging to logfile defined in config.json.
logger_path = File.dirname(__FILE__) + '/../serveralert.log'
Logger.instance.file = logger_path

# Instantiate Help Desk API with config.json credentials.
api = HelpDeskAPI.new(help_desk['email'], help_desk['password'])

assignee_id = nil
api.users.each do |user|
  if user['email'] == help_desk['assignee_email']
    assignee_id = user['id']
  end
end
unless assignee_id
  puts "Failed to find assignee email #{help_desk['assignee_email']} in Spiceworks users."
  exit
end

# Instantiate Mailer with config.json email settings
mailer = Mailer.new(email['smtp'], email['port'], email['domain'], email['from'], email['password'], email['to'])

# Create workers for all servers defined in config.json.
workers = []
config['servers'].each do |server|
  workers.push(Worker.new(server['hostname'], server['ip'], api, assignee_id, mailer, locker))
end

# Start background jobs to run workers on interval.
scheduler = Rufus::Scheduler.new
scheduler.every interval do
  workers.each { |worker| worker.run }
end

# Redirect scheduler errors to log file.
def scheduler.on_error(job, error)
  Logger.instance.error "Scheduler error in #{job.id}: #{error.message}"
end

# Blocks until all backgound workers are finished.
# Since workers never finish this will keep program from ending.
scheduler.join
