require 'sqlite3'
require 'singleton'
require 'digest'

class Database
  include Singleton

  LOCKED = 1
  UNLOCKED = 0

  def open(file)
    if File.exist? file
      @db = SQLite3::Database.new file
    else
      initDatabase file
    end
  end

  def insert(name, ip)
    uid = hash name, ip
    query = "INSERT INTO servers (uid, name, ip, locked, ticket_id) VALUES (?, ?, ?, ?, ?)"
    @db.execute(query, uid, name, ip, 0, nil)
  end

  def find(name, ip)
    uid = hash name, ip
    query = "SELECT * FROM servers WHERE uid = \"#{uid}\""
    @db.execute(query).first
  end

  def lock(name, ip)
    uid = hash name, ip
    query = "UPDATE servers SET locked = #{LOCKED} WHERE uid = \"#{uid}\""
    @db.execute(query)
  end

  def unlock(name, ip)
    uid = hash name, ip
    query = "UPDATE servers SET locked = #{UNLOCKED} WHERE uid = \"#{uid}\""
    @db.execute(query)
  end

  def locked?(name, ip)
    uid = hash name, ip
    query = "SELECT locked FROM servers WHERE uid = \"#{uid}\""
    @db.execute(query).first.first == LOCKED
  end

  def ticket(name, ip, ticket_id)
    uid = hash name, ip
    query = "UPDATE servers SET ticket_id = #{ticket_id} WHERE uid = \"#{uid}\""
    @db.execute(query)
  end

  private

  def hash(name, ip)
    Digest::SHA256.hexdigest(name+ip)[0..5]
  end

  def initDatabase(file)
    @db = SQLite3::Database.new file
    @db.execute <<-SQL
      create table servers (
        uid varchar(5),
        name varchar(10),
        ip varchar(10),
        locked boolean,
        ticket_id int
      );
    SQL
  end
end
