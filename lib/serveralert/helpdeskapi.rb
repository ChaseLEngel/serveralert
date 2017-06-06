require 'rest-client'
require 'nokogiri'
require 'json'

class HelpDeskAPI

  module Priority
    HIGH = '1'
    MEDIUM = '2'
    LOW = '3'
  end

  URL = 'https://on.spiceworks.com/'
  API_URL = URL + 'api/'

  def initialize(username, password)
    @api = RestClient::Resource.new(API_URL)
    @username = username
    @password = password
    @authenticity_token = nil
    @creator_id = nil
    @cookies = nil
  end

  # Authenicate user and set cookies.
  # This will be called automatically on endpoint request.
  def sign_in()
    # Contact sign in page to set cookies.
    begin
      sign_in_res = RestClient.get(URL + 'sign_in')
    rescue RestClient::ExceptionWithResponse => error
      puts "Error contacting #{URL + 'sign_in'}: #{error}"
      raise
    end

    # Parse authenticity_token from sign in form.
    page = Nokogiri::HTML(sign_in_res)
    @authenticity_token = page.css('form').css('input')[1]['value']
    unless @authenticity_token
      puts 'Error parsing authenticity_token: Token not found.'
      raise
    end
    # Parse sign_in HTML for csrf-token
    page.css('meta').each do |tag|
      @csrf_token = tag['content'] if tag['name'] == 'csrf-token'
    end
    unless @csrf_token
      puts 'Error: No csrf-token found'
      raise
    end

    # Set cookies for later requests
    @cookies = sign_in_res.cookies

    # Simulate sign in form submit button.
    body = {'authenticity_token': @authenticity_token, 'user[email_address]': @username, 'user[password]': @password}
    RestClient.post(URL + 'sessions', body, {:cookies => @cookies}) do |response, request, result, &block|
      # Response should be a 302 redirect from /sessions
      if responseError?(response)
        puts "Error contacting #{URL + 'sessions'}: #{error}"
        raise
      end
      # Update cookies just incase
      @cookies = response.cookies
    end
  end

  # Returns array of all tickets
  def all()
    request('GET', 'tickets/all')['tickets']
  end

  # Returns array of all open tickets
  def open()
    request('GET', 'tickets/open')['tickets']
  end

  # Returns array of all closed tickets
  def closed()
    request('GET', 'tickets/closed')['tickets']
  end

  # Returns array of all users
  def users()
    request('GET', 'users')['users']
  end

  # Submits a new ticket returns created ticket
  def newTicket(summary, description, assignee_id, priority)
    payload = JSON.generate(
      {
        'ticket': {
          summary: summary,
          description: description,
          priority: priority,
          due_at: nil,
          updated_at: nil,
          created_at: nil,
          organization_id: organization_id,
          assignee_id: assignee_id,
          assignee_type: 'User',
          creator_id: creator_id,
          creator_type: 'User',
          custom_values: [],
          ticket_category_id: nil,
          ticket_category_type: nil,
          watchers: []
        }
      })
    headers = {'authenticity_token': @authenticity_token, 'X-CSRF-Token': @csrf_token, 'Content-Type': 'application/json'}
    request('POST', 'tickets', payload, headers)['tickets'].first
  end

  # Creates a comment for given ticket id.
  def newComment(ticket_id, comment)
    payload = JSON.generate(
      {
        'comment':{
          'created_at': nil,
          'activity_type': 'comment',
          'body': comment,
          'ticket_id': ticket_id,
          'creator_id': nil,
          'creator_type': nil
        },
        'ticket_comment': {
          'created_at': nil,
          'activity_type': 'comment',
          'body': comment,
          'ticket_id': ticket_id,
          'creator_id': nil,
          'creator_type': nil,
          'initial_upload_ids': []
        }
      }
    )
    headers = {'authenticity_token': @authenticity_token, 'X-CSRF-Token': @csrf_token, 'Content-Type': 'application/json'}
    request('POST', "tickets/#{ticket_id}/comments", payload, headers)
  end

  private
  # Returns organization_id by parsing existing tickets.
  # At least one ticket MUST exist when this is called.
  def organization_id
    return @organization_id if @organization_id
    tickets = all
    if tickets.empty?
      puts "No tickets exist to parse organization_id from."
      raise
    end
    @organization_id = tickets.first['organization_id']
  end

  # Returns creator_id for current user from users endpoint
  def creator_id
    unless
      users.each do |user|
        @creator_id = user['id'] if user['email'] == @username
      end
      unless @creator_id
        puts "Failed to find creator_id for user: #{@username}"
        raise
      end
    end
    return @creator_id
  end

  # Returns true if response cotains HTTP error code.
  def responseError?(response)
    error_codes = [400, 401, 402, 403, 404, 500, 501, 502, 503]
    error_codes.include? response.code
  end

  # Contact API given endpoint and return JSON
  def request(method, endpoint, payload = nil, headers = {})
    # If cookies are not set already assume we need to login.
    unless @cookies
      sign_in
    end
    headers = headers.merge({:cookies => @cookies})
    endpoint_response = nil
    case method
      when 'POST'
        @api[endpoint].post(payload, headers) do |response, request, result, &block|
          if responseError?(response)
            puts "Error contacting #{response.request.url} with HTTP code: #{response.code}"
            raise
          end
          # Update cookies just incase
          @cookies = response.cookies
          endpoint_response = response
        end
      when 'GET'
        endpoint_response = @api[endpoint].get(headers)
        if responseError?(endpoint_response)
          puts "Error contacting #{response.request.url} with HTTP code: #{response.code}"
          raise
        end
      else
        puts "Error: Unknown HTTP method #{method}"
        raise
    end
    JSON.parse endpoint_response
  end
end
