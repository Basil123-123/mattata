local utils = {}
local redis = dofile('libs/redis.lua')
local configuration = dofile('configuration.lua')
local json = require('dkjson')

local mattata = {}
local api = {}
local tools = {}

function utils:init(configuration, token)
    mattata = self
    api = self.api
    tools = self.tools
    return utils
end

function utils.is_trusted_user(chat_id, user_id)
    if redis:sismember('administration:' .. chat_id .. ':trusted', user_id) then
        return true
    end
    return false
end

function utils.service_message(message)
    if message.new_chat_member then
        return true, 'new_chat_member'
    elseif message.left_chat_member then
        return true, 'left_chat_member'
    elseif message.new_chat_title then
        return true, 'new_chat_title'
    elseif message.new_chat_photo then
        return true, 'new_chat_photo'
    elseif message.delete_chat_photo then
        return true, 'delete_chat_photo'
    elseif message.group_chat_created then
        return true, 'group_chat_created'
    elseif message.supergroup_chat_created then
        return true, 'supergroup_chat_created'
    elseif message.channel_chat_created then
        return true, 'channel_chat_created'
    elseif message.migrate_to_chat_id then
        return true, 'migrate_to_chat_id'
    elseif message.migrate_from_chat_id then
        return true, 'migrate_from_chat_id'
    elseif message.pinned_message then
        return true, 'pinned_message'
    elseif message.successful_payment then
        return true, 'successful_payment'
    end
    return false
end

function utils.is_media(message)
    if message.audio or message.document or message.game or message.photo or message.sticker or message.video or message.voice or message.video_note or message.contact or message.location or message.venue or message.invoice then
        return true
    end
    return false
end

function utils.media_type(message)
    if message.audio then
        return 'audio'
    elseif message.document then
        return 'document'
    elseif message.game then
        return 'game'
    elseif message.photo then
        return 'photo'
    elseif message.sticker then
        return 'sticker'
    elseif message.video then
        return 'video'
    elseif message.voice then
        return 'voice'
    elseif message.video_note then
        return 'video note'
    elseif message.contact then
        return 'contact'
    elseif message.location then
        return 'location'
    elseif message.venue then
        return 'venue'
    elseif message.invoice then
        return 'invoice'
    elseif message.forward_from or message.forward_from_chat then
        return 'forwarded'
    elseif message.text then
        return message.text:match('[\216-\219][\128-\191]') and 'rtl' or 'text'
    end
    return ''
end

function utils.file_id(message)
    if message.audio then
        return message.audio.file_id
    elseif message.document then
        return message.document.file_id
    elseif message.sticker then
        return message.sticker.file_id
    elseif message.video then
        return message.video.file_id
    elseif message.voice then
        return message.voice.file_id
    elseif message.video_note then
        return message.video_note.file_id
    end
    return ''
end

function utils.get_user_count()
    return #redis:keys('user:*:info')
end

function utils.get_group_count()
    return #redis:keys('chat:*:info')
end

function utils.clear_broadcast_memory()
    local broadcasts = redis:keys('broadcasted:*')
    for k, v in pairs(broadcasts) do
        if redis:get(v) then
            redis:del(v)
        end
    end
end

function utils.get_user_language(user_id)
    return redis:hget('chat:' .. user_id .. ':settings', 'language') or 'en_gb'
end

function utils.get_log_chat(chat_id)
    return redis:hget('chat:' .. chat_id .. ':settings', 'log chat') or configuration.log_channel or false
end

function utils.get_list(name)
    name = tostring(name)
    local length = redis:llen(name)
    return redis:lrange(name, 0, tonumber(length) - 1)
end

function utils.send_reply(message, text, parse_mode, disable_web_page_preview, reply_markup, token)
    reply_markup = reply_markup or {
        ['remove_keyboard'] = true
    }
    parse_mode = tostring(parse_mode):lower()
    if parse_mode ~= 'markdown' and parse_mode ~= 'html' then
        parse_mode = nil
    end
    return mattata.api.send_message(message, text, parse_mode, disable_web_page_preview, false, message.message_id, reply_markup, token)
end

function utils:toggle_user_setting(chat_id, user_id, setting)
    if not chat_id or not user_id or not setting then
        return false
    end
    if not self.settings[tostring(chat_id)] then
        self.settings[tostring(chat_id)] = {}
    end
    if not self.settings[tostring(chat_id)][tonumber(user_id)] then
        self.settings[tostring(chat_id)][tonumber(user_id)] = {}
    end
    if not self.settings[tostring(chat_id)][tonumber(user_id)][tostring(setting)] then
        local success = false
        if setting == 'restrict messages' then
            success = mattata.api.restrict_chat_member(chat_id, user_id, os.time(), false)
        elseif setting == 'restrict media messages' then
            success = mattata.api.restrict_chat_member(chat_id, user_id, os.time(), nil, false)
        elseif setting == 'restrict other messages' then
            success = mattata.api.restrict_chat_member(chat_id, user_id, os.time(), nil, nil, false)
        elseif setting == 'restrict web page previews' then
            success = mattata.api.restrict_chat_member(chat_id, user_id, os.time(), nil, nil, nil, false)
        end
        if success then
            if setting == 'restrict messages' then
                self.settings[tostring(chat_id)][tonumber(user_id)]['restrict media messages'] = true
                self.settings[tostring(chat_id)][tonumber(user_id)]['restrict other messages'] = true
                self.settings[tostring(chat_id)][tonumber(user_id)]['restrict web page previews'] = true
            end
            self.settings[tostring(chat_id)][tonumber(user_id)][tostring(setting)] = true
            return true
        end
        return success
    end
    local success = false
    if setting == 'restrict messages' then
        success = mattata.api.restrict_chat_member(chat_id, user_id, os.time(), true)
    elseif setting == 'restrict media messages' then
        success = mattata.api.restrict_chat_member(chat_id, user_id, os.time(), nil, true)
    elseif setting == 'restrict other messages' then
        success = mattata.api.restrict_chat_member(chat_id, user_id, os.time(), nil, nil, true)
    elseif setting == 'restrict web page previews' then
        success = mattata.api.restrict_chat_member(chat_id, user_id, os.time(), nil, nil, nil, true)
    end
    if success then
        if setting == 'restrict messages' then
            self.settings[tostring(chat_id)][tonumber(user_id)]['restrict media messages'] = nil
            self.settings[tostring(chat_id)][tonumber(user_id)]['restrict other messages'] = nil
            self.settings[tostring(chat_id)][tonumber(user_id)]['restrict web page previews'] = nil
        end
        self.settings[tostring(chat_id)][tonumber(user_id)][tostring(setting)] = nil
        return true
    end
    return success
end

function utils:get_user_setting(chat_id, user_id, setting)
    if not chat_id or not user_id or not setting then
        return false
    end
    if not self.settings[tostring(chat_id)] then
        self.settings[tostring(chat_id)] = {}
    end
    if not self.settings[tostring(chat_id)][tonumber(user_id)] then
        self.settings[tostring(chat_id)][tonumber(user_id)] = {}
    end
    if not self.settings[tostring(chat_id)][tonumber(user_id)][tostring(setting)] then
        return false
    end
    return true
end

function utils.is_group(message)
    if not message or not message.chat or not message.chat.type or message.chat.type == 'private' then
        return false
    end
    return true
end

function utils.get_user_message_statistics(user_id, chat_id)
    return {
        ['messages'] = tonumber(redis:get('messages:' .. user_id .. ':' .. chat_id)) or 0,
        ['name'] = redis:hget('user:' .. user_id .. ':info', 'first_name'),
        ['id'] = user_id
    }
end

function utils.reset_message_statistics(chat_id)
    if not chat_id or tonumber(chat_id) == nil then
        return false
    end
    local messages = redis:keys('messages:*:' .. chat_id)
    if not next(messages) then
        return false
    end
    for k, v in pairs(messages) do
        redis:del(v)
    end
    return true
end

function utils.input(s)
    local mentioned_user = false
    if not s then
        return false
    elseif type(s) == 'table' then
        if s.entities and #s.entities >= 2 and s.entities[2].type == 'text_mention' then
            mentioned_user = tostring(s.entities[2].user.id)
        end
        s = s.text
    end
    if s:lower():match('^mattata search %a+ for .-$') then
        return s:lower():match('^mattata search %a+ for (.-)$')
    elseif not s:lower():match('^[%%/%%!%%$%%^%%?%%&%%%%]') then
        return s
    end
    local input = s:find(' ')
    if not input then
        return false
    end
    s = s:sub(input + 1)
    input = s:find(' ')
    if mentioned_user then
        s = input and mentioned_user .. ' ' .. s:sub(input + 1) or mentioned_user
    end
    return s
end

function utils.get_input(message, has_reason)
    local input = utils.input(message)
    if message.reply then
        if not message.reply.from or message.reply.forward_from then
            return false
        elseif has_reason and input then
            return message.reply.from.id, input
        end
        return message.reply.from.id
    elseif not input then
        return false
    elseif has_reason and input:find(' ') then
        return input:match('^(.-) '), input:match(' (.-)$')
    end
    return input
end

function utils.get_chat_id(chat)
    if not chat then
        return false
    end
    local success = api.get_chat(chat)
    if not success or not success.result then
        return false
    end
    return success.result.id
end

function utils.get_data_file(file_name)
    local file = io.open('data/' .. file_name)
    if not file then
        print('Are you sure I have the relevant file permissions to read/write to this location? [data/' .. file_name .. ']')
        return false
    end
    local body = file:read('*all')
    file:close()
    body = json.decode(body)
    if type(body) ~= 'table' then
        return {}
    end
    return body
end

function utils.update_chat(chat)
    return utils.update_chat_data(chat.id, 'info.json', chat)
end

function utils.update_user(user)
    return utils.update_user_data(user.id, 'info.json', user)
end

function utils:get_setting(chat_id, setting)
    if not self.settings[tostring(chat_id)] or self.settings[tostring(chat_id)][setting] == nil then
        return false
    end
    return self.settings[tostring(chat_id)][setting]
end

function utils:get_value(chat_id, key)
    if not self.values[tostring(chat_id)] then
        self.values[tostring(chat_id)] = {}
    end
    if self.values[tostring(chat_id)][key] == nil then
        return false
    end
    return self.values[tostring(chat_id)][key]
end

function utils:set_value(chat_id, key, value)
    if not self.values[tostring(chat_id)] then
        self.values[tostring(chat_id)] = {}
    end
    self.values[tostring(chat_id)][key] = value
    return true
end

function utils:update_setting(chat_id, setting, value)
    if not self.settings[tostring(chat_id)] then
        self.settings[tostring(chat_id)] = {}
    end
    self.settings[tostring(chat_id)][setting] = value
    return true
end

function utils:delete_setting(chat_id, setting)
    if not self.settings[tostring(chat_id)] then
        self.settings[tostring(chat_id)] = {}
    end
    self.settings[tostring(chat_id)][setting] = nil
    return true
end

function utils:delete_value(chat_id, key)
    if not self.values[tostring(chat_id)] then
        self.values[tostring(chat_id)] = {}
    end
    self.values[tostring(chat_id)][key] = nil
    return true
end

function utils.log_error(error_message)
    error_message = tostring(error_message):gsub('%%', '%%%%')
    local output = string.format('%s[31m[Error] %s%s[0m', string.char(27), error_message, string.char(27))
    print(output)
end

function utils.update_data_file(file_name, data)
    if type(data) ~= 'table' then
        return false
    end
    data = json.encode(data, {
        ['indent'] = true
    })
    return utils.write_file('data/', file_name, data)
end

function utils:enable_plugin(chat_id, plugin)
    if not self.disabled_plugins[tostring(chat_id)] then
        self.disabled_plugins[tostring(chat_id)] = {}
    end
    self.disabled_plugins[tostring(chat_id)][plugin] = nil
    return true
end

function utils:disable_plugin(chat_id, plugin)
    if not self.disabled_plugins[tostring(chat_id)] then
        self.disabled_plugins[tostring(chat_id)] = {}
    end
    self.disabled_plugins[tostring(chat_id)][plugin] = true
    return true
end

function utils.write_file(file_path, file_name, content)
    file_path = tostring(file_path)
    if not file_path:match('/$') then
        file_path = file_path .. '/'
    end
    file_name = tostring(file_name)
    content = tostring(content)
    local file, message, code = io.open(file_path .. file_name, 'w+')
    if tonumber(code) == 2 then
        os.execute('mkdir -p ' .. file_path)
        file, message, code = io.open(file_path .. file_name, 'w+')
        if code ~= nil then
            return content
        end
    end
    local success = file:write(content)
    file:close()
    return success, file, content
end

function utils.does_language_exist(language)
    return pcall(function()
        return dofile('languages/' .. language .. '.lua')
    end)
end

function utils.is_valid(message) -- Performs basic checks on the message object to see if it's fit
-- for its purpose. If it's valid, this function will return `true` - otherwise it will return `false`.
    if not message then -- If the `message` object is nil, then we'll ignore it.
        return false, 'No `message` object exists!'
    elseif message.date < os.time() - 7 then -- We don't want to process old messages, so anything
    -- older than the current system time (giving it a leeway of 7 seconds).
        return false, 'This `message` object is too old!'
    elseif not message.from then -- If the `message.from` object doesn't exist, this will likely
    -- break some more code further down the line!
        return false, 'No `message.from` object exists!'
    end
    return true
end

function utils.insert_keyboard_row(keyboard, first_text, first_callback, second_text, second_callback, third_text, third_callback)
    table.insert(keyboard['inline_keyboard'], {
        {
            ['text'] = first_text,
            ['callback_data'] = first_callback
        },
        {
            ['text'] = second_text,
            ['callback_data'] = second_callback
        },
        {
            ['text'] = third_text,
            ['callback_data'] = third_callback
        }
    })
    return keyboard
end

function mattata.get_inline_list(username, offset)
    offset = offset and tonumber(offset) or 0
    local inline_list = {}
    table.sort(mattata.inline_plugin_list)
    for k, v in pairs(mattata.inline_plugin_list) do
        if k > offset and k < offset + 50 then -- The bot API only accepts a maximum of 50 results, hence we need the offset.
            v = v:gsub('\n', ' ')
            table.insert(
                inline_list,
                api.inline_result():type('article'):id(tostring(k)):title(v:match('^(/.-) %- .-$')):description(v:match('^/.- %- (.-)$')):input_message_content(
                    api.input_text_message_content(
                        string.format(
                            '• %s - %s\n\nTo use this command inline, you must use the syntax:\n@%s %s',
                            v:match('^(/.-) %- .-$'),
                            v:match('^/.- %- (.-)$'),
                            username,
                            v:match('^(/.-) %- .-$')
                        )
                    )
                ):reply_markup(
                    api.inline_keyboard():row(
                        api.row():switch_inline_query_button('Show me how!', v:match('^(/.-) '))
                    )
                )
            )
        end
    end
    return inline_list
end

function utils:toggle_setting(chat_id, setting, value)
    value = (type(value) ~= 'string' and tostring(value) ~= 'nil') and value or true
    local settings = self.settings[tostring(chat_id)] or {}
    if not chat_id or not setting or type(settings) ~= 'table' then
        return false
    end
    settings[setting] = (settings[setting] == nil) and value or nil
    self.settings[tostring(chat_id)] = settings
    return true
end

function utils:uses_administration(chat_id)
    return utils.get_setting(self, message.chat.id, 'use administration')
end

function utils.format_time(seconds)
    if not seconds or tonumber(seconds) == nil then
        return false
    end
    local output = ''
    seconds = tonumber(seconds) -- Make sure we're handling a numerical value
    local minutes = math.floor(seconds / 60)
    if minutes == 0 then
        return seconds ~= 1 and seconds .. ' seconds' or seconds .. ' second'
    elseif minutes < 60 then
        return minutes ~= 1 and minutes .. ' minutes' or minutes .. ' minute'
    end
    local hours = math.floor(seconds / 3600)
    if hours == 0 then
        return minutes ~= 1 and minutes .. ' minutes' or minutes .. ' minute'
    elseif hours < 24 then
        return hours ~= 1 and hours .. ' hours' or hours .. ' hour'
    end
    local days = math.floor(seconds / 86400)
    if days == 0 then
        return hours ~= 1 and hours .. ' hours' or hours .. ' hour'
    elseif days < 7 then
        return days ~= 1 and days .. ' days' or days .. ' day'
    end
    local weeks = math.floor(seconds / 604800)
    if weeks == 0 then
        return days ~= 1 and days .. ' days' or days .. ' day'
    else
        return weeks ~= 1 and weeks .. ' weeks' or weeks .. ' week'
    end
end

----------------------
---- HANDLE LINKS ----
----------------------

function utils.check_links(message, get_links, only_valid, whitelist)
    local links = {}
    if message.entities then
        for i = 1, #message.entities do
            if message.entities[i].type == 'text_link' then
                message.text = message.text .. ' ' .. message.entities[i].url
            end
        end
    end
    for n in message.text:lower():gmatch('%@[%w_]+') do
        table.insert(links, n:match('^%@([%w_]+)$'))
    end
    for n in message.text:lower():gmatch('t%.me/joinchat/[%w_]+') do
        table.insert(links, n:match('/(joinchat/[%w_]+)$'))
    end
    for n in message.text:lower():gmatch('t%.me/[%w_]+') do
        if not n:match('/joinchat$') then
            table.insert(links, n:match('/([%w_]+)$'))
        end
    end
    for n in message.text:lower():gmatch('telegram%.me/joinchat/[%w_]+') do
        table.insert(links, n:match('/(joinchat/[%w_]+)$'))
    end
    for n in message.text:lower():gmatch('telegram%.me/[%w_]+') do
        if not n:match('/joinchat$') then
            table.insert(links, n:match('/([%w_]+)$'))
        end
    end
    for n in message.text:lower():gmatch('telegram%.dog/joinchat/[%w_]+') do
        table.insert(links, n:match('/(joinchat/[%w_]+)$'))
    end
    for n in message.text:lower():gmatch('telegram%.dog/[%w_]+') do
        if not n:match('/joinchat$') then
            table.insert(links, n:match('/([%w_]+)$'))
        end
    end
    if whitelist then
        local count = 0
        for k, v in pairs(links) do
            redis:set('whitelisted_links:' .. message.chat.id .. ':' .. v:lower(), true)
            count = count + 1
        end
        return string.format(
            '%s link%s ha%s been whitelisted in this chat!',
            count,
            count == 1 and '' or 's',
            count == 1 and 's' or 've'
        )
    end
    local checked = {}
    local valid = {}
    for k, v in pairs(links) do
        if not redis:get('whitelisted_links:' .. message.chat.id .. ':' .. v:lower()) and not utils.is_whitelisted_link(v:lower()) then
            if v:match('^joinchat/') then
                return true
            elseif not table.contains(checked, v) then
                local success = api.get_chat(v:lower())
                if success and success.result and success.result.type ~= 'private' then
                    if not get_links then
                        return true
                    end
                    table.insert(valid, v:lower())
                end
                table.insert(checked, v:lower())
            end
        end
    end
    if get_links then
        if only_valid then
            return valid
        end
        return checked
    end
    return false
end

function utils.is_whitelisted_link(link)
    if link == 'username' or link == 'isiswatch' or link == 'mattata' or link == 'telegram' then
        return true
    end
    return false
end

--------------------------
---- PROCESS STICKERS ----
--------------------------

function utils.process_stickers(message)
    if message.chat.type == 'supergroup' and message.sticker and message.file_id then
        -- Process each sticker to see if they are one of the configured, command-performing stickers.
        for k, v in pairs(configuration.stickers.ban) do
            if message.file_id == v then
                message.text = '/ban'
            end
        end
        for k, v in pairs(configuration.stickers.warn) do
            if message.file_id == v then
                message.text = '/warn'
            end
        end
        for k, v in pairs(configuration.stickers.kick) do
            if message.file_id == v then
                message.text = '/kick'
            end
        end
    end
    return message
end

-----------------------
---- GET CHAT INFO ----
-----------------------

function utils.get_user(input)
    input = tostring(input)
    input = input:match('^%@(.-)$') or input
    if tonumber(input) == nil then
        input = redis:get('username:' .. input:lower())
    end
    if not input or tonumber(input) == nil then
        return false
    end
    local success = utils.load_chat_info(input)
    if success and type(success) == 'table' and success.result then
        return success
    end
    return api.get_chat(input)
end

function utils.load_chat_info(chat_id, search_usernames)
    if search_usernames and tonumber(chat_id) == nil then
        chat_id = redis:get('username:' .. tostring(chat_id):lower())
    end
    if not chat_id then
        return false
    end
    local file = io.open('data/chats/' .. tostring(chat_id) .. '/info.json') or io.open('data/users/' .. tostring(chat_id) .. '/info.json')
    if not file then
        return false
    end
    local data = file:read('*all')
    file:close()
    data = json.decode(data)
    if type(data) ~= 'table' then
        return false
    end
    return {
        ['ok'] = true,
        ['result'] = data
    }
end

function utils:is_plugin_disabled(chat_id, plugin)
    chat_id = (type(chat_id) == 'table' and chat_id.chat) and chat_id.chat.id or chat_id
    if not self.disabled_plugins[tostring(chat_id)] then
        return false
    elseif self.disabled_plugins[tostring(chat_id)][plugin] then
        return true
    end
    return false
end

------------------------------
---- CHECKING PERMISSIONS ----
------------------------------

function utils:is_group_admin(chat_id, user_id, is_real_admin)
    if utils.is_global_admin(chat_id) or utils.is_global_admin(user_id) then
        return true
    elseif not is_real_admin and utils.is_group_mod(self, chat_id, user_id) then
        return true
    end
    local admins = api.get_chat_administrators(chat_id)
    if not admins then
        return false
    end
    for _, admin in ipairs(admins.result) do
        if admin.user.id == user_id then
            return true
        end
    end
    return false
end

function utils.is_global_admin(id)
    for k, v in pairs(configuration.admins) do
        if id == v then
            return true
        end
    end
    return false
end

function utils:is_group_mod(chat_id, user_id)
    if not chat_id or not user_id then
        return false
    end
    if self.mods and self.mods[tonumber(user_id)] then
        return true
    end
    return false
end

function utils.is_group_owner(chat_id, user_id)
    local is_owner = false
    local user = api.get_chat_member(chat_id, user_id)
    if user.status == 'creator' then
        is_owner = true
    end
    return is_owner
end

function utils.is_privacy_enabled(user_id)
    return redis:exists('user:' .. user_id .. ':opt_out')
end

function utils.is_user_blacklisted(message)
    if not message or not message.from or not message.chat then
        return false
    end
    local global = redis:get('global_blacklist:' .. message.from.id) -- Check if the user is globally
    -- blacklisted from using the bot.
    local group = redis:get('group_blacklist:' .. message.chat.id .. ':' .. message.from.id) -- Check
    -- if the user is blacklisted from using the bot in the current group, or globally for that matter.
    if global or group then
        if global and message.chat.type ~= 'private' and not redis:sismember('global_blacklist_unban:' .. message.chat.id, message.from.id) then
        -- If the user is globally blacklisted, and they haven't been banned before for this reason, add them to a set to exclude them from future checks.
            local success = api.ban_chat_member(message.chat.id, message.from.id) -- Attempt to ban the blacklisted user.
            local output = message.from.first_name .. ' [' .. (message.from.username and '@' .. message.from.username or message.from.id) .. '] is globally blacklisted.'
            output = success and output .. ' For this reason, I have banned them from this group. If you choose to unban them, I will not ban them next time they join!' or ' I tried to ban them, but it seems I don\'t have the required permission to do this. You might like to consider banning them manually, since users on this global blacklist are present because they have flooded or caused other havoc in other groups.'
            api.send_message(message.chat.id, output) -- Alert the group of this user's presence on the global blacklist.
            redis:sadd('global_blacklist_unban:' .. message.chat.id, message.from.id)
        end
        return true
    end
    return false
end

--------------------
---- STATISTICS ----
--------------------

function utils.get_message_statistics(self)
    local message = self.message
    local language = self.language
    if not message or not language then
        return language['errors']['generic']
    end
    local users = redis:smembers('chat:' .. message.chat.id .. ':users')
    local user_info = {}
    for i = 1, #users do
        local user = utils.get_user_message_statistics(users[i], message.chat.id)
        if user.name and user.name ~= '' and user.messages > 0 and not utils.is_privacy_enabled(user.id) then
            table.insert(user_info, user)
        end
    end
    table.sort(user_info, function(a, b)
        if a.messages and b.messages then
            return a.messages > b.messages
        end
    end)
    local total = 0
    for n, user in pairs(user_info) do
        local message_count = user_info[n].messages
        total = total + message_count
    end
    local text = ''
    local output = {}
    for i = 1, 10 do table.insert(output, user_info[i]) end
    for k, v in pairs(output) do
        local message_count = v.messages
        local percent = tostring(tools.round((message_count / total) * 100, 1))
        text = text .. tools.escape_html(v.name) .. ': <b>' .. tools.comma_value(message_count) .. '</b> [' .. percent .. '%]\n'
    end
    if not text or text == '' then
        return language['statistics']['1']
    end
    return string.format(language['statistics']['2'], tools.escape_html(message.chat.title), text, tools.comma_value(total))
end

--------------------
---- MODERATION ----
--------------------

function utils.load_chat_data(chat_id, file_name)
    if not chat_id or not file_name then
        return false
    end
    local file = io.open('data/chats/' .. tostring(chat_id) .. '/' .. tostring(file_name))
    if not file then
        return false
    end
    local data = file:read('*all')
    file:close()
    data = json.decode(data)
    if type(data) ~= 'table' then
        return {}
    end
    return data
end

function utils.update_chat_data(chat_id, file_name, data)
    local file, message, code = io.open('data/chats/' .. tostring(chat_id) .. '/' .. tostring(file_name), 'w+')
    if tonumber(code) == 2 then
        os.execute('mkdir -p data/chats/' .. tostring(chat_id) .. '/')
        file, message, code = io.open('data/chats/' .. tostring(chat_id) .. '/' .. tostring(file_name), 'w+')
        if code ~= nil then
            if configuration.debug then
                print(message, code)
            end
            return data
        end
    end
    data = json.encode(data, {
        ['indent'] = true
    })
    local success = file:write(data)
    file:close()
    return success, data
end

function utils.load_user_data(user_id, file_name)
    if not user_id or not file_name then
        return false
    end
    local file = io.open('data/users/' .. tostring(user_id) .. '/' .. tostring(file_name))
    if not file then
        return false
    end
    local data = file:read('*all')
    file:close()
    data = json.decode(data)
    if type(data) ~= 'table' then
        return {}
    end
    return data
end

function utils.update_user_data(user_id, file_name, data)
    local file, message, code = io.open('data/users/' .. tostring(user_id) .. '/' .. tostring(file_name), 'w+')
    if tonumber(code) == 2 then
        os.execute('mkdir -p data/users/' .. tostring(user_id) .. '/')
        file, message, code = io.open('data/users/' .. tostring(user_id) .. '/' .. tostring(file_name), 'w+')
        if code ~= nil then
            if configuration.debug then
                print(message, code)
            end
            return data
        end
    end
    data = json.encode(data, {
        ['indent'] = true
    })
    local success = file:write(data)
    file:close()
    return success, data
end

function utils:get_mods(chat_id)
    return self.mods[tostring(chat_id)] or {}
end

function utils:add_mod(chat_id, user_id)
    self.mods[tostring(chat_id)] = self.mods[tostring(chat_id)] or {}
    if self.mods[tostring(chat_id)][tonumber(user_id)] then
        return false, 'This user is already a moderator of this chat!'
    end
    self.mods[tostring(chat_id)][tonumber(user_id)] = true
    return true, 'This user is now a moderator of this chat!'
end

function utils:remove_mod(chat_id, user_id)
    self.mods[tostring(chat_id)] = self.mods[tostring(chat_id)] or {}
    if not self.mods[tostring(chat_id)][tonumber(user_id)] then
        return false, 'This user was not a moderator of this chat!'
    end
    self.mods[tostring(chat_id)][tonumber(user_id)] = nil
    return true, 'This user is no longer a moderator of this chat!'
end

function utils:get_custom_commands(chat_id)
    return self.custom_commands[tostring(chat_id)] or {}
end

function utils:add_custom_command(chat_id, command, value)
    self.custom_commands[tostring(chat_id)] = self.custom_commands[tostring(chat_id)] or {}
    if self.custom_commands[tostring(chat_id)][tostring(command)] then
        return false, 'This custom command already exists!'
    end
    self.custom_commands[tostring(chat_id)][tostring(command)] = tostring(value)
    return true, 'That text will now be sent whenever that custom command is used!'
end

function utils:remove_custom_command(chat_id, command)
    self.custom_commands[tostring(chat_id)] = self.custom_commands[tostring(chat_id)] or {}
    if not self.custom_commands[tostring(chat_id)][tostring(command)] then
        return false, 'That custom command does not exist!'
    end
    self.custom_commands[tostring(chat_id)][tostring(command)] = nil
    return true, 'That custom command has been deleted!'
end

function utils:get_inline_help(input, offset)
    offset = offset and tonumber(offset) or 0
    local inline_help = {}
    local count = offset + 1
    table.sort(self.plugin_list)
    for k, v in pairs(self.plugin_list) do
        if k > offset and k < offset + 50 then -- The bot API only accepts a maximum of 50 results, hence we need the offset.
            v = v:gsub('\n', ' ')
            if v:match('^/.- %- .-$') and v:lower():match(input) then
                local result_type = 'article'
                local id = tostring(count)
                local title, description = v:match('^(/.-) %- (.-)$')
                local output = string.format('%s %s - %s', utf8.char(8226), title, description)
                local input_message_content = api.input_text_message_content(output)
                local result = api.inline_result():type(result_type):id(id):title(title):description(description):input_message_content(input_message_content)
                table.insert(inline_help, result)
                count = count + 1
            end
        end
    end
    return inline_help
end

function utils:get_inline_list(offset)
    offset = offset and tonumber(offset) or 0
    local inline_list = {}
    table.sort(self.inline_plugin_list)
    for k, v in pairs(self.inline_plugin_list) do
        if k > offset and k < offset + 50 then -- The bot API only accepts a maximum of 50 results, hence we need the offset.
            v = v:gsub('\n', ' ')
            local result_type = 'article'
            local id = tostring(k)
            local title, description = v:match('^(/.-) %- (.-)$')
            local output = tools.symbols.bullet .. ' %s - %s\n\nTo use this command inline, you must use the following syntax:\n@%s %s'
            local formatted_output = string.format(output, title, description, self.info.username, title)
            local input_message_content = api.input_text_message_content(output)
            local reply_markup = api.inline_keyboard():row(api.row():switch_inline_query_button('Show me how!', title))
            local result = api.inline_result():type(result_type):id(id):title(title):description(description):input_message_content(input_message_content):reply_markup(reply_markup)
            table.insert(inline_list, result)
        end
    end
    return inline_list
end

function utils:get_help()
    local help = {}
    local count = 1
    table.sort(self.plugin_list)
    for k, v in pairs(self.plugin_list) do
        if v:match('^/.- %- .-$') then
            table.insert(help, utf8.char(8226) .. ' ' .. v:match('^(/.-) %- .-$'))
            count = count + 1
        end
    end
    return help
end

_G.table.contains = function(tab, match)
    for _, val in pairs(tab) do
        if tostring(val):lower() == tostring(match):lower() then
            return true
        end
    end
    return false
end

_G.table.random = function(tab, seed)
    if seed and tonumber(seed) ~= nil then
        math.randomseed(seed)
    end
    tab = type(tab) == 'table' and tab or { tostring(tab) }
    local total = 0
    for key, chance in pairs(tab) do
        total = total + chance
    end
    local choice = math.random() * total
    for key, chance in pairs(tab) do
        choice = choice - chance
        if choice < 0 then
            return key
        end
    end
end

_G.string.hexdump = function(data, length, size, space)
    data = tostring(data)
    size = (tonumber(size) == nil or tonumber(size) < 1) and 1 or tonumber(size)
    space = (tonumber(space) == nil or tonumber(space) < 1) and 8 or tonumber(space)
    length = (tonumber(length) == nil or tonumber(length) < 1) and 32 or tonumber(length)
    local output = {}
    local column = 0
    for i = 1, #data, size do
        for j = size, 1, -1 do
            local sub = string.sub(data, i + j - 1, i + j - 1)
            if #sub > 0 then
                local byte = string.byte(sub)
                local formatted = string.format('%.2x', byte)
                table.insert(output, formatted)
            end
        end
        if column % space == 0 then
            table.insert(output, ' ')
        end
        if (i + size - 1) % length == 0 then
            table.insert(output, '\n')
        end
        column = column + 1
    end
    return table.concat(output)
end

return utils