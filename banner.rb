# frozen_string_literal: true

module AntiRaid
  require 'discordrb'
  require 'yaml'

  @config = YAML.load_file('config.yml')

  count = @config[:servers].count
  puts "[INFO] Loading with #{count} server#{'s' if count != 1} configured!"

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
  end

  @bot.message do |event|
    next if @config[:servers][event.server.id].nil?

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
