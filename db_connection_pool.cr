require "db"

# TODO after some amount of time, reduce pool size if it's over min size.
# TODO wait
class DBConnectionPool
  SLEEP_TIME = 0.01

  def initialize(@db_url, @min_size = 5, @max_size = 40)
    @pool = [] of DB
    @used = [] of DB
    @lock = Mutex.new
    init_pool
  end

  # TODO wait
  def take(wait = false)
    @lock.lock

    grow_pool if @pool.empty? && @used.size < @max_size

    if @pool.empty?
      @lock.unlock
      if wait
        sleep(SLEEP_TIME)
        return take(wait)
      else
        return nil
      end
    end

    conn = @pool.shift
    @used << conn
    @lock.unlock
    conn
  end

  def return(conn)
    @lock.lock
    @used.delete(conn)
    if health_ok?(conn)
      @pool << conn
    else
      conn.close
      @pool << DB.open(@db_url)
    end
    @lock.unlock
  end

  def finalize
    (@pool + @used).each &.close
  end

  private def init_pool
    add_to_pool(@min_size)
  end

  private def grow_pool
    n = Math.min(@used.size, @max_size - @used.size)
    add_to_pool(n)
  end

  private def add_to_pool(n)
    n.times do
      @pool << DB.open(@db_url)
    end
  end

  private def health_ok?(conn)
    begin
      conn.exec "select 1"
    rescue ex
      puts "connection #{conn} failed health check: #{ex}"
      return false
    end
    true
  end

  private def close(conn)
    begin
      conn.close
    rescue ex
      puts "error closing db connection #{conn}: #{ex}"
    end
  end    
end
