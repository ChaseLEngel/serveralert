require 'json'
require 'rufus-scheduler'

require File.dirname(__FILE__) + '/serveralert/helpdeskapi'
require File.dirname(__FILE__) + '/serveralert/mailer'
require File.dirname(__FILE__) + '/serveralert/logger'
require File.dirname(__FILE__) + '/serveralert/config'
require File.dirname(__FILE__) + '/serveralert/worker'
require File.dirname(__FILE__) + '/serveralert/server'
require File.dirname(__FILE__) + '/serveralert/database'

database_path = File.dirname(__FILE__) + '/../serveralert.sqlite3'
Database.instance.open database_path

# Parse config.json
config_path = File.dirname(__FILE__) + '/../config.json'
config = Config.new config_path

logger_path = File.dirname(__FILE__) + '/../serveralert.log'
Logger.instance.file = logger_path

# Instantiate Help Desk API with config.json credentials.
api = HelpDeskAPI.new(config.settings.help_desk.email, config.settings.help_desk.password)

assignee_id = nil
api.users.each do |user|
  if user['email'] == config.settings.help_desk.assignee_email
    assignee_id = user['id']
  end
end
unless assignee_id
  puts "Failed to find assignee email #{config.settings.help_desk.assignee_email} in Spiceworks users."
  exit
end

# Instantiate Mailer with config.json email settings
mailer = Mailer.new(config.settings.email.smtp,
                    config.settings.email.port,
                    config.settings.email.domain,
                    config.settings.email.from,
                    config.settings.email.password,
                    config.settings.email.to)

# Create workers for all servers defined in config.json.
workers = []
config.servers.each do |server|
  workers.push(Worker.new(server, api, assignee_id, mailer))
end

# Start background jobs to run workers on interval.
scheduler = Rufus::Scheduler.new
scheduler.every config.settings.interval do
  workers.each { |worker| worker.run }
end

# Redirect scheduler errors to log file.
def scheduler.on_error(job, error)
  Logger.instance.error "Scheduler error in #{job.id}: #{error.message}"
end

# Blocks until all backgound workers are finished.
# Since workers never finish this will keep program from ending.
scheduler.join
