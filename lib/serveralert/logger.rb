require 'singleton'

# Log messages to a file.
class Logger
  include Singleton
  attr_writer :file, :debug_level, :verbose

  def initialize
    @file ||= 'atv.log'
    @debug_level ||= false
    @verbose ||= false
  end

  def info(message)
    write format_message('INFO', message)
  end

  def error(message)
    write format_message('ERROR', message)
  end

  def warn(message)
    write format_message('WARN', message)
  end

  def debug(message)
    return unless @debug_level
    write format_message('DEBUG', message)
  end

  private

  def format_message(type, message)
    "[#{Time.now}] #{type} - #{message}"
  end

  def write(message)
    puts message if @verbose
    File.open(@file, 'a').syswrite (message + "\n")
  end
end
