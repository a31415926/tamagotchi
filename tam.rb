require 'sqlite3'
require 'net/http'
require 'json'

module Main
    def read_console
        return gets.chomp
    end
end

module Logger
    def log(text, file = 'act')
        path = File.dirname(File.expand_path(__FILE__))
        text = "[#{Time::now}]: #{text}\n"
        File::write(File::join(path, "#{file}.log"), text, mode: 'a+')
    end
end

class Telegram
    include Logger

    def initialize(token = '5522599958:AAH4IOOUHj5-XlafYBc0cItA0E7-qSBIpy0')
        # да-да-да, так открытым нельзя хранить токен :(
        @token = token
    end

    def url(method)
        return "https://api.telegram.org/bot#{@token}/#{method}"
    end            

    def send_message(to, text)
        data = {chat_id: to, text: text}
        send_request(url('sendMessage'), data)
    end

    def send_request(url, data)
        uri = URI(url)
        http = Net::HTTP::new(uri.hostname, uri.port)
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req.body = data.to_json
        http.use_ssl = true
        resp = http.request(req)

        log(resp.body)
    end
end


class Tamagotchi
    attr_reader :satiety, :drowsiness, :name

    include Main
    include Logger

    def initialize
        fdir = File.dirname(File.expand_path(__FILE__))
        @db = SQLite3::Database.open(File.join(fdir, 'tamagotchi.db'))
        @db.results_as_hash = true
        create_table
        p 'New tamagotchi (1) or select(2) ?'
        type = read_console.to_i
        if type == 1
            p 'Enter name tamagotchi:'
            id = new_tamagochi(read_console)
        elsif type == 2
            all_tamagotchi
            p 'Enter ID:'
            id = read_console.to_i
        end
        t = select_tamagotchi(id)
        raise 'Tamagotchi not found' unless t

        @id = t['id']
        @name = t['name']
        @satiety = t['satiety']
        @drowsiness = t['drowsiness']
    end


    def check_stat
        if !@satiety.between?(1, 14) || !@drowsiness.between?(1, 14)
            kill(':(')
        elsif @satiety < 4
            p 'i want eat'
        elsif @satiety > 10
            p "stop eating, please"
        elsif @drowsiness > 10
            p 'stop sleeping, please'
        elsif @drowsiness < 4
            p 'i want sleep'
        end
    end 

    def stat
        puts "Name: #{@name}\ndrowsiness: #{@drowsiness}\nsatiety: #{@satiety}"
    end

    def eat
        @satiety += 2
        @drowsiness -= 2
        update_stat
    end

    def asleep
        @satiety -= 2
        @drowsiness += 2
        update_stat
    end

    def walk
        @satiety -= 2
        @drowsiness -= 2
        update_stat
    end

    def kill(reason = '')
        unless reason.length > 0
            p 'Reason:'
            reason = read_console
        end
        @db.execute("DELETE FROM tamagotchi WHERE id=?", @id)
        kill_text = "tamagotchi #{@name} (id #{@id}) dead. reason: #{reason}"
        log(kill_text)
        Telegram.new.send_message(456008920, kill_text)
        exit
    end

    private

    def update_stat
        @db.execute("UPDATE tamagotchi SET satiety = ?, drowsiness = ? WHERE id=?", [@satiety, @drowsiness, @id])
    end

    def all_tamagotchi
        stm = @db.prepare("SELECT id, name FROM tamagotchi ORDER BY date_created")
        rst = stm.execute
        p 'select ID tamagotchi: '
        while (row = rst.next) do 
            p "#{row['id']}. #{row['name']}"
        end
    end

    def select_tamagotchi(id)
        stm = @db.query("SELECT * FROM tamagotchi WHERE id=?", id)
        return stm.next
    end

    def create_table
        @db.execute "CREATE TABLE IF NOT EXISTS tamagotchi(
            id INTEGER PRIMARY KEY,
            name VARCHAR,
            date_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            satiety INTEGER DEFAULT 6,
            drowsiness INTEGER DEFAULT 9
        )"
    end

    def new_tamagochi(name)
        log("new tamagotchi: #{name}")
        @db.execute("INSERT INTO tamagotchi (name) VALUES (?)", [name])
        return @db.last_insert_row_id
    end
end



animal = Tamagotchi.new
puts "Select command:
            eat
            sleep
            walk
            kill
            stat
        "
while true
    case animal.read_console
    when "eat"
        animal.eat
    when "sleep"
        animal.asleep
    when "stat"
        animal.stat
    when "kill"
        animal.kill
    when "walk"
        animal.walk
    when "exit"
        p 'Goodbye'
        exit
    else 
        p 'Unknown command'
    end
    animal.check_stat
end