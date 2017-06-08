require File.dirname(__FILE__) + '/logger'
require File.dirname(__FILE__) + '/mailer'
require File.dirname(__FILE__) + '/helpdeskapi'

# Handles pinging ip and creating Help Desk ticket on failure.
class Worker
  def initialize(server, api, assignee_id, mailer)
    @server = server
    @api = api
    @mailer = mailer
    @assignee_id = assignee_id
    @mail_subject = "Failed to submit Help Desk ticket for #{@server.name}"
    @ticket_title = "Server #{@server.name} is offline"
    @ticket_message = "
      Server #{@server.name}(#{@server.ip}) did not respond in time.\n
      Please make sure it is powered on and connected to the network.\n
      This is an automated response.
    "
    @ticket_priority = HelpDeskAPI::Priority::HIGH
    Logger.instance.info "Starting worker for #{@server.name} #{@server.ip}"
  end

  def mail_body(error)
    "
      Failed to create Help Desk ticket for #{@server.name}(#{@server.ip})\n
      #{error}
    "
  end

  # Sends ping to ip
  # If server does not respond a Help Desk ticket is submitted.
  # If Help Desk ticket submitting fails an email to sent to alert failure.
  def run
    Logger.instance.info "Worker running ping for #{@server.name}"
    if !@server.ping?
      # Don't create ticket if one has already been created.
      if @server.locked?
        Logger.instance.info "No response from #{@server.name}. Help Desk Ticket already submitted. Skipping"
        return
      end
      Logger.instance.info "No response from #{@server.name}. Submitting Help Desk ticket."
      @server.lock
      begin
        @server.ticket_id = @api.newTicket(@ticket_title, @ticket_message, @assignee_id, @ticket_priority)['id']
      rescue Exception => error
        Logger.instance.error "Failed to submit Help Desk ticket: #{error}"
        @mailer.send(@mail_subject, mail_body(error))
        raise error
      end
    elsif @server.locked?
      # Comment on existing ticket that server is online.
      begin
        if @server.ticket_id
          Logger.instance.error "Server #{@server.name} is locked but doesn't have ticket_id set. Unlocking."
        else
          Logger.instance.info "Server #{@server.name} is back online. Sending comment to ticket #{@server.ticket_id}."
          @api.newComment(@server.ticket_id, "Server #{@server.name} is back online.")
        end
      rescue Exception => error
        message = "Failed to comment on Help Desk ticket #{@server.ticket_id}: #{error}"
        Logger.instance.error message
        @mailer.send("Failed to comment on Help Desk ticket", message)
      end
      # Allow new tickets to be created for this server.
      @server.unlock
    end
  end
end
