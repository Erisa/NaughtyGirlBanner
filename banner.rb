module AntiRaid
  require 'discordrb'
  require 'yaml'

  @config = YAML.load_file('config.yml')

  @count = @config[:servers].count
  puts "[INFO] Loading with #{@count} server#{'s' if @count != 1} configured!"

  @bot = Discordrb::Bot.new(token: @config[:token])

  @bot.ready do |event|
    puts '[INFO] Bot is ready!'
    puts '[INFO] Found the following servers:'
    @config[:servers].each_key do |sid|
      server = event.bot.server(sid)
      if server.nil?
        puts "[WARN] - Server with ID #{sid} not recognised. Bot may not function as expected."
      else
        print "[INFO] - #{self.server_name(event.bot.server(sid))} (#{sid})"
        puts " - #{server.members.count} Members"
      end
    end
    @bot.watching = "over #{@count} servers."
  end

  @bot.message do |event|
    next if @config[:servers][event.server.id].nil?

    if event.message.content.start_with?("ngb ping")
      return_message = event.respond('Pinging..!')
        ping = (return_message.id - event.message.id) >> 22
	      choose = %w(i o e u y a)
        return_message.edit("P#{choose.sample}ng! (`#{ping}ms`)")
    end

    if event.message.content.start_with?("ngb eval")
      next if event.user.id != @config[:owner]
      args = event.message.content.delete_prefix('ngb eval ').split(' ')
      begin
        msg = event.respond "Evaluating..."
        init_time = Time.now
        result = eval args.join(' ')
        result = result.to_s
        if result.nil? || result == '' || result == ' ' || result == "\n"
          msg.edit "Done! (No output)\nCommand took #{(Time.now - init_time)} seconds to execute!"
          next
        end
        str = ''
        if result.length >= 1984
          str << "Your output exceeded the character limit! (`#{result.length - 1984}`/`1984`)"
          str << "But hastebin support was not implemented. Sorry."
        else
          str << "Output: ```\n#{result}```Command took #{(Time.now - init_time)} seconds to execute!"
        end
        msg.edit(str)
        rescue Exception => e
        msg.edit("An error has occured!! ```ruby\n#{e}```\nCommand took #{(Time.now - init_time)} seconds to execute!")
      end
    end


    begin
      diff = Time.now - event.user.on(event.server).joined_at
    rescue StandardError => e
      @bot.user(@config[:owner]).pm("Error occured trying to process join time for <@#{event.user.id}> in #{self.server_name(event.server)} (`#{event.server.id}`): ```ruby\n#{e}```\nJoined at: `#{event.user.on(event.server).joined_at}`")
      diff = 9_999_999_999
    end

    if @config[:servers][event.server.id][:blacklist] == true && diff < @config[:join_threshold] && @config[:blacklist].any? { |word| event.message.content.downcase.include?(word.downcase) }
      begin
        event.message.delete
      rescue StandardError
        nil
      end
      puts "[INFO] Crossbanning #{event.user.id}."
      crossban(event.user, event.server)
    elsif @config[:servers][event.server.id][:hard_blacklist] == true && @config[:hard_blacklist].any? { |word| event.message.content.downcase.include?(word.downcase) }
      begin
        event.message.delete
      rescue StandardError => e
        puts "[ERROR] Can't delete message by #{event.user.id} in #{event.server.id}: #{e}"
        @bot.user(@config[:owner]).pm("Error occured trying to delete message by <@#{event.user.id}> from #{self.server_name(event.server)} (`#{event.server.id}`): ```ruby\n#{e}```")
        next
      end
      msg = event.respond "#{event.user.mention} pls dont say mean words :(("
      sleep 2
      msg.delete
    end
  end

  def self.crossban(user, origin_server = nil, invoker = nil, automated = true, reason = 'No reason provided.')
    invoker = @bot.user(@config[:owner]) if invoker.nil?

    @config[:servers].each_key do |sid|
      server = @bot.server(sid)
      if automated
        full_reason = "[ Automated crossban by #{invoker.distinct} ]: Possible raid message in #{self.server_name(origin_server)}."
      elsif origin_server.nil?
        full_reason = "[ Crossban by #{invoker.distinct} in Unknown Server ]: #{reason}"
      elsif origin_server == server
        full_reason = "[ Crossban by #{invoker.distinct} ]: #{reason}"
      else
        full_reason = "[ Crossban by #{invoker.distinct} in #{self.server_name(origin_server)}]: #{reason}"
      end
      begin
        server.ban(user, 7, reason: full_reason)
      rescue StandardError => e
        puts "[ERROR^] #{e}"
        @bot.user(@config[:owner]).pm("Error occured trying to ban <@#{user.id}> from #{self.server_name(server)} (`#{sid}`): ```ruby\n#{e}```")
      end
    end
  end

  def self.server_name(server)
    @config[:servers][server.id][:name].nil? ? server.name : @config[:servers][server.id][:name]
  end

  # why did you enable this
  if @config[:debug]
    require 'pry'
    @bot.run(true)
    binding.pry
  else
    @bot.run
  end
end
