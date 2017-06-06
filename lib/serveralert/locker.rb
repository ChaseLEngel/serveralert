require 'json'

class Locker
  def initialize(file)
    @file = file
  end

  def lock(id)
    write(id, true)
  end

  def unlock(id)
    write(id, false)
  end

  def locked?(id)
    parse[id] == true
  end

  private
  def parse
    return {} unless File.exist? @file
    data = File.read(@file)
    return {} if data.empty?
    JSON.parse(File.read(@file))
  end

  def write(id, value)
    data = JSON.generate(parse.merge({id => value}))
    file = File.new(@file, 'w')
    file.syswrite(data)
    file.close
  end
end
