require 'json'

class Config

  NoConfigFile = Class.new(StandardError)

  def initialize(file)
    unless File.exist? file
      fail NoConfigFile, "#{file} does not exist or is not a file."
    end
    @config = JSON.parse(file)
  end
end
