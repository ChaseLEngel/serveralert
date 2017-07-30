require 'json'
require 'rufus-scheduler'
require 'HelpDeskAPI'

require File.dirname(__FILE__) + '/serveralert/mailer'
require File.dirname(__FILE__) + '/serveralert/logger'
require File.dirname(__FILE__) + '/serveralert/config'
require File.dirname(__FILE__) + '/serveralert/worker'
require File.dirname(__FILE__) + '/serveralert/server'
require File.dirname(__FILE__) + '/serveralert/database'

# Open SQLite3 database
Database.instance.open File.dirname(__FILE__) + '/../serveralert.sqlite3'

# Parse config.json
config = Config.new File.dirname(__FILE__) + '/../config.json'

Logger.instance.file = File.dirname(__FILE__) + '/../serveralert.log'

# Instantiate Help Desk API with config.json credentials.
HelpDeskAPI::Client.new config.settings.help_desk.email, config.settings.help_desk.password

assignee_id = nil
HelpDeskAPI::Users.users.each do |user|
  if user.email == config.settings.help_desk.assignee_email
    assignee_id = user.id
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
  workers.push Worker.new(server, assignee_id, mailer)
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
