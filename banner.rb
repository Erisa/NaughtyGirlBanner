module AntiRaid
  require "discordrb"
  require "yaml"

  @config = YAML.load_file("config.yml")

  count = @config[:servers].count
  puts "[INFO] Loading with #{count} server#{"s" if count != 1} configured!"

  @bot = Discordrb::Bot.new(token: @config[:token])

  @bot.ready do |event|
    puts "[INFO] Bot is ready!"
    puts "[INFO] Found the following servers:"
    @config[:servers].each_key { |sid|
      server = event.bot.server(sid)
      if server.nil?
        puts "[WARN] - Server with ID #{sid} not recognised. Bot may not function as expected."
      else
        puts "[INFO] - #{event.bot.server(sid).name} (#{sid})"
      end
    }
  end

  @bot.message do |event|
    next if @config[:servers][event.server.id].nil?

    begin
      diff = Time.now - event.author.joined_at
    rescue => exception
      @bot.user(@config[:owner]).pm("Error occured trying to process join time for <@#{event.user.id}> in #{event.server.name} (`#{event.server.id}`): ```ruby\n#{exception}```")
      diff = 9999999999
    end

    if (@config[:servers][event.server.id][:blacklist] == true && diff < @config[:join_threshold] && @config[:blacklist].any? { |word| event.message.content.downcase.include?(word.downcase) })
      event.message.delete rescue nil
      puts "[INFO] Crossbanning #{event.user.id}."
      self.crossban(event.user, event.server)
    elsif @config[:servers][event.server.id][:hard_blacklist] == true && @config[:hard_blacklist].any? { |word| event.message.content.downcase.include?(word.downcase) }
      begin
        event.message.delete
      rescue => exception
        puts "[ERROR] Can't delete message by #{event.user.id} in #{event.server.id}: #{exception}"
        @bot.user(@config[:owner]).pm("Error occured trying to delete message by <@#{event.user.id}> from #{event.server.name} (`#{event.server.id}`): ```ruby\n#{exception}```")
        next
      end
      msg = event.respond "#{event.user.mention} pls dont say mean words :(("
      sleep 2
      msg.delete
    end
  end

  def self.crossban(user, origin_server = nil, invoker = nil, automated = true, reason = "No reason provided.")
    if invoker.nil?
      invoker = @bot.user(@config[:owner])
    end

    @config[:servers].each_key { |sid|
      server = @bot.server(sid)
      if automated
        full_reason = "[ Automated crossban by #{invoker.distinct} ]: Possible raid message in #{origin_server.name}."
      elsif origin_server.nil?
        full_reason = "[ Crossban by #{invoker.distinct} in Unknown Server ]: #{reason}"
      elsif origin_server == server
        full_reason = "[ Crossban by #{invoker.distinct} ]: #{reason}"
      else
        full_reason = "[ Crossban by #{invoker.distinct} in #{origin_server.name}]: #{reason}"
      end
      begin
        server.ban(user, 7, reason: full_reason)
      rescue => exception
        puts "[ERROR^] #{exception}"
        @bot.user(@config[:owner]).pm("Error occured trying to ban <@#{user.id}> from #{server.name} (`#{sid}`): ```ruby\n#{exception}```")
      end
    }
  end

  @bot.run
end
