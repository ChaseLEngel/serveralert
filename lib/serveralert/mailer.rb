require File.dirname(__FILE__) + '/logger'

require 'mail'

class Mailer
  def initialize(smtp, port, domain, from, password, to)
    @smtp = smtp
    @port = port
    @domain = domain
    @from = from
    @password = password
    @to = to
    initMail
  end

  def initMail
    # mail gem doesn't like instance variables.
    smtp = @smtp
    port = @port
    domain = @domain
    from = @from
    password = @password
    Mail.defaults do
      delivery_method :smtp, {
        address: smtp,
        port: port,
        domain: domain,
        user_name: from,
        password: password,
        authentication: :login,
        enable_starttls_auto: true
      }
    end
  end

  def send(mail_subject, mail_body)
    Logger.instance.info "Sending email to: '#{@to}', subject: '#{mail_subject}'"
    # mail gem doesn't like instance variables.
    fromer = @from
    toer = @to
    puts fromer
    Mail.deliver do
      from fromer
      to toer
      subject mail_subject
      body mail_body
    end
  end
end
