local command = 'location <query>'
local doc = [[```
/location <query>
Returns a location from Google Maps.
Alias: /loc
```]]

local triggers = {
	'^/location[@'..bot.username..']*',
	'^/loc[@'..bot.username..']* ',
	'^/loc[@'..bot.username..']*$'
}

local action = function(msg)

	local input = utilities.input(msg.text)
	if not input then
		if msg.reply_to_message and msg.reply_to_message.text then
			input = msg.reply_to_message.text
		else
			sendMessage(msg.chat.id, doc, true, msg.message_id, true)
			return
		end
	end

	local coords = get_coords(input)
	if type(coords) == 'string' then
		sendReply(msg, coords)
		return
	end

	sendLocation(msg.chat.id, coords.lat, coords.lon, msg.message_id)

end

return {
	action = action,
	triggers = triggers,
	doc = doc,
	command = command
}
