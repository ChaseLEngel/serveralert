require File.dirname(__FILE__) + '/logger'
require File.dirname(__FILE__) + '/mailer'

# Handles pinging ip and creating Help Desk ticket on failure.
class Worker
  def initialize(server, assignee_id, mailer)
    @server = server
    @mailer = mailer
    @assignee_id = assignee_id
    @mail_subject = "Failed to submit Help Desk ticket for #{@server.name}"
    @ticket_title = "Server #{@server.name} is offline"
    @ticket_message = "
      Server #{@server.name}(#{@server.ip}) did not respond in time.\n
      Please make sure it is powered on and connected to the network.\n
      This is an automated response.
    "
    @ticket_priority = HelpDeskAPI::Ticket::Priority::HIGH

    Logger.instance.info "Starting worker for #{@server.name} #{@server.ip}"
  end

  def mail_body(error)
    "
      Failed to create Help Desk ticket for #{@server.name}(#{@server.ip})\n
      #{error}
    "
  end

  def run
    Logger.instance.info "Worker running ping for #{@server.name}"

    # Sends ping to server ip
    if !@server.ping?
      send_ticket_and_lock
    elsif @server.locked? # True if ticket has been submitted(locked) and ping has responsed.
      send_comment_and_unlock
    end
  end

  def send_ticket_and_lock
      # Don't create ticket if one has already been created.
      if @server.locked?
        Logger.instance.info "No response from #{@server.name}. Help Desk Ticket already submitted. Skipping"
        return
      end

      Logger.instance.info "No response from #{@server.name}. Submitting Help Desk ticket."

      # Create and submit new ticket.
      ticket = HelpDeskAPI::Ticket.new @ticket_title, @ticket_message, @assignee_id, @ticket_priority

      begin
        ticket.submit
      rescue Exception => error
        Logger.instance.error "Failed to submit Help Desk ticket: #{error}"
        @mailer.send(@mail_subject, mail_body(error))
        raise error
      end


      # Lock server so no other ticket can be sent.
      @server.lock

      # Save ticket id in database
      @server.ticket_id = ticket.id

      # Ticket id should never be nil
      if @server.ticket_id.nil?
        msg = "Ticket submitted for #{@server.name} but returned nil ticket_id."
        Logger.instance.error msg
        @mailer.send(@mail_subject, mail_body(msg))
      end
  end

  def send_comment_and_unlock
    if @server.ticket_id.nil?
      Logger.instance.error "Server #{@server.name} is locked but doesn't have ticket_id set. Unlocking."
      @server.unlock
      return
    end

    Logger.instance.info "Server #{@server.name} is back online. Sending comment to ticket #{@server.ticket_id}."
    comment = HelpDeskAPI::Comment.new @server.ticket_id, "Server #{@server.name} is back online."

    begin
      comment.save
    rescue Exception => error
      message = "Failed to comment on Help Desk ticket #{@server.ticket_id}: #{error}"
      Logger.instance.error message
      @mailer.send("Failed to comment on Help Desk ticket", message)
    end

    # Allow new tickets to be created for this server.
    @server.unlock
  end
end
