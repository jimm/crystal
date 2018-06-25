require "mysql"

DB.open "mysql://root@localhost/test" do |db|
  begin
    db.query "select count(*) from users" do |rs|
      rs.each do
        puts "there are #{rs.read(Int64)} users"
      end
    end
  ensure
    db.close
  end
end
