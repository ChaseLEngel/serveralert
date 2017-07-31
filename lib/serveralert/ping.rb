require 'open3'

class Ping
  # count: Stop after sending number of packets.
  # wait: Number of seconds to wait between sending each packet.
  def initialize(host, count = 1, wait = 1)
    @host = host.to_s
    @count = count.to_i
    @wait = wait.to_i
  end

  # Sends ICMP request to host.
  # Returns true if a response is recieved.
  # Returns false if no response was recieved.
  # Raises exception if execution of ping fails.
  def ping?
    cmd = "ping -c #{@count} -i #{@wait} #{@host}"

    # Execute command and handle resulting exit status from command.
    Open3.popen3(cmd) do |_, _, stderr, thread|
      case thread.value.exitstatus
      when 0 # At least one response was heard from the specified host.
        return true
      when 2 # The transmission was successful but no responses were received.
        return false
      else # Error
        raise StandardError, "Failed to execute command: #{cmd.inspect}"
      end
    end
  end
end
