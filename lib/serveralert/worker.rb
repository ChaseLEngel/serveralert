require File.dirname(__FILE__) + '/logger'
require File.dirname(__FILE__) + '/mailer'
require File.dirname(__FILE__) + '/helpdeskapi'

require 'net/ping/external'

# Handles pinging ip and creating Help Desk ticket on failure.
class Worker
  def initialize(friendly_name, ip, api, assignee_id, mailer, locker)
    @friendly_name = friendly_name
    @ticket_id = nil
    @ip = ip
    @api = api
    @mailer = mailer
    @locker = locker
    @assignee_id = assignee_id
    @mail_subject = "Failed to submit Help Desk ticket for #{@friendly_name}"
    @ticket_title = "Server #{@friendly_name} is offline"
    @ticket_message = "
      Server #{@friendly_name}(#{@ip}) did not respond in time.\n
      Please make sure it is powered on and connected to the network.\n
      This is an automated response.
    "
    @ticket_priority = HelpDeskAPI::Priority::HIGH
    @pinger = Net::Ping::External.new(@ip)
    Logger.instance.info "Starting worker for #{@friendly_name} #{@ip}"
  end

  def mail_body(error)
    "
      Failed to create Help Desk ticket for #{@friendly_name}(#{@ip})\n
      #{error}
    "
  end

  # Sends ping to ip
  # If server does not respond a Help Desk ticket is submitted.
  # If Help Desk ticket submitting fails an email to sent to alert failure.
  def run()
    Logger.instance.info "Worker running ping for #{@friendly_name}"
    if !@pinger.ping?
      # Don't create ticket if one has already been created.
      if @locker.locked?(@friendly_name)
          Logger.instance.info "No response from #{@friendly_name}. Help Desk Ticket already submitted. Skipping"
        return
      end
      Logger.instance.info "No response from #{@friendly_name}. Submitting Help Desk ticket."
      @locker.lock(@friendly_name)
      begin
        ticket = @api.newTicket(@ticket_title, @ticket_message, @assignee_id, @ticket_priority)
        @ticket_id = ticket['id']
      rescue Exception => error
        Logger.instance.error "Failed to submit Help Desk ticket: #{error}"
        @mailer.send(@mail_subject, mail_body(error))
        raise error
      end
    elsif @locker.locked?(@friendly_name)
      # Comment on existing ticket that server is online.
      begin
        if @ticket_id.nil?
          Logger.instance.error "Server #{@friendly_name} is locked but doesn't have ticket_id set. Unlocking."
        else
          Logger.instance.info "Server #{@friendly_name} is back online. Sending comment to ticket #{@ticket_id}."
          @api.newComment(@ticket_id, "Server #{@friendly_name} is back online.")
        end
      rescue Exception => error
        message = "Failed to comment on Help Desk ticket #{@ticket_id}: #{error}"
        Logger.instance.error message
        @mailer.send("Failed to comment on Help Desk ticket", message)
      end
      # Allow new tickets to be created for this server.
      @locker.unlock(@friendly_name)
    end
  end
end
