-- require
local http = require "gamesense/http"
local ip_check = "https://api.ipify.org"
local easing = require "gamesense/easing"
local images = require "gamesense/images"
local anti_aim = require "gamesense/antiaim_funcs"
local Discord = require "gamesense/discord_webhooks"
--local Webhook = Discord.new("https://discord.com/api/webhooks/909889882527264788/6mGSXTpCE_wSNsoykUL9JNth-oU79hbo-LdTTTQDVSn--RW8AT-Al7FG95D3S-Ls1XTG")


-- global variables
local reub = 76561198384716464
local width, height = client.screen_size()

-- panorama 
local js = panorama.open()
local name, steamid = js.MyPersonaAPI.GetName() , js.MyPersonaAPI.GetXuid()
local menuR, menuG, menuB, menuA = ui.get(ui.reference("Misc", "Settings", "Menu color"))

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

-- ragebot stats variables
local stats = {
	total_shots = 0,
	hits = 0,
	misses = 0,
	miss_type = "",
	head_hit = 0,
	body_hit = 0,
	limbs_hit = 0,
	min_dmg = 0,
	miss_or_hit = ""
}

-- buybot variables
local primary = {
	{
		primary_name = "None",
		primary_console = " "
	},
	{
		primary_name = "awp",
		primary_console = "awp"
	},
	{
		primary_name = "ssg08",
		primary_console = "ssg08"
	},
	{
		primary_name = "scar20 / g3sg1",
		primary_console = "scar20; buy g3sg1"
	}
}
  
local secondary = {
	{
	  	secondary_name = "None",
	  	secondary_console = " "
	},
	{
		secondary_name = "p250",
		secondary_console = "p250"
	},
	{
		secondary_name = "tec-9",
		secondary_console = "tec9"
	},
	{
		secondary_name = "five-seven",
		secondary_console = "fiveseven"
	},
	{
	   	secondary_name = "dual berettas",
	  	secondary_console = "elite"
	},
	{
	  	secondary_name = "deagle / revolver",
	  	secondary_console = "deagle ;buy revolver"
	}
}

local nade = {
	{
		nade_name = "decoy"
	},
	{
		nade_name = "molotov"
 	},
	{
		nade_name = "he nade"
	},
	{
		nade_name = "flash"
	},
	{
	  	nade_name = "smoke"
	}
}

local other = {
	{
		other_name = "kevlar"
	},
	{
		other_name = "full kevlar"
	},
	{
		other_name = "zeus"
	},
	{
	   	other_name = "defuser"
	}
}

local _primary = {}
for _, v in pairs(primary) do
  _primary[#_primary + 1] = v.primary_name
end

local _secondary = {}
for _, v in pairs(secondary) do
  _secondary[#_secondary + 1] = v.secondary_name
end

local _nade = {}
for _, v in pairs(nade) do
	_nade[#_nade + 1] = v.nade_name
end

local _other = {}
for _, v in pairs(other) do
  _other[#_other + 1] = v.other_name
end

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

-- shot logger variables
local hitgroup_names = {"body", "head", "chest", "stomach", "left arm", "right arm", "left leg", "right leg", "neck", "unknown", "gear"}

-- menu elements (lua, a tab)
-- hud elements
ui.new_label("LUA", "A", "Hud Elements")
watermark_checkbox = ui.new_checkbox("LUA", "A", "Watermark")
indicators_checkbox = ui.new_checkbox("LUA", "A", "Indicators")
player_stats_checkbox = ui.new_checkbox("LUA", "A", "Ragebot Stats")
hitlogs = ui.new_checkbox("LUA", "A", "Hitlog")
hitlog_options = ui.new_multiselect("LUA", "A", "Hitlog Options", {"Console", "Screen"})
--divider
ui.new_label("LUA", "A", " ")
-- improvements
ui.new_label("LUA", "A", "Improvements")
fast_grenade = ui.new_checkbox("LUA", "A", "Fast Grenade")
better_doubletap = ui.new_checkbox("LUA", "A", "Better Doubletap")
--divider
ui.new_label("LUA", "A", " ")
-- misc elements
ui.new_label("LUA", "A", "Misc Elements")
clantag_checkbox = ui.new_checkbox("LUA", "A", "Clantag")
set_console = ui.new_checkbox("LUA", "A", "Filter console")
--divider
ui.new_label("LUA", "A", " ")

-- menu elements (lua, b tab)
ui.new_label("LUA", "B", "Other Elements")
match_crosshair = ui.new_checkbox("LUA", "B", "Matching Crosshair Color")
--divider
ui.new_label("LUA", "B", " ")
-- buybot elements
ui.new_label("LUA", "B", "Buybot")
buybot_button = ui.new_checkbox("LUA", "B", "Enable Buybot")
primary_combo = ui.new_combobox("LUA", "B", "Primary Selection", _primary)
secondary_combo = ui.new_combobox("LUA", "B", "Secondary Selection", _secondary)
nade_multi = ui.new_multiselect("LUA", "B", "Nade Selection", _nade)
other_multi = ui.new_multiselect("LUA", "B", "Misc Selection", _other)

-- set visibility
ui.set_visible(ui.reference("RAGE", "Aimbot", "Log misses due to spread"), false)
ui.set_visible(ui.reference("Visuals", "Other esp", "Feature indicators"), false)

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
    sv_maxusrcmdprocessticks = ui.reference("MISC", "Settings", "sv_maxusrcmdprocessticks"),
}

-- easing "thing"
do
    for key, easing_func in pairs(easing) do
        easing[key] = function (t, b, c, d, ...)
            return math.clamp(easing_func(t, b, c, d, ...), b, d)
        end
    end
end

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

-- multiselect function
local function table_contains(table, value)
    for k, v in pairs(table) do if v == value then return true end end
    return false
end

-- time to ticks function
local function time_to_ticks(t)
	return math.floor(0.5 + (t / globals.tickinterval()))
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

-- paint
-- menu stuff
local function menu()
	if ui.is_menu_open() then

		client.exec("developer 1")
		client.exec("con_filter_enable 1")
		client.exec("con_filter_text gamesense")

		-- crosshair /done
		client.exec("cl_crosshaircolor_r ", menuR, "; cl_crosshaircolor_g ", menuG, "; cl_crosshaircolor_b ", menuB)

		local qpm, qpcolor = ui.reference("RAGE", "Other", "Quick peek assist mode")
		ui.set(qpcolor, menuR, menuG, menuB, menuA)

		local oofc, oofcolor = ui.reference("VISUALS", "Player ESP", "Out of fov arrow")
		ui.set(oofcolor, menuR, menuG, menuB, menuA)
		
		-- color
		menuR, menuG, menuB, menuA = ui.get(ui.reference("Misc", "Settings", "Menu color"))

		-- menu position
		local mx, my = ui.menu_position()

		--menu size
		local mw, mh = ui.menu_size()
	
		-- left side
		renderer.gradient(mx - 1, my + 1, 1, mh, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)
		-- bottom side
		renderer.gradient(mx, my + mh, mw, 1, menuR, menuG, menuB, menuA, menuR, menuG, menuB, menuA, true)
		-- right side
		renderer.gradient(mx + mw, my + 1, 1, mh, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)


		if ui.get(buybot_button) then
			ui.set_visible(primary_combo, true)
			ui.set_visible(secondary_combo, true)
			ui.set_visible(nade_multi, true)
			ui.set_visible(other_multi, true)
		else 
			ui.set_visible(primary_combo, false)
			ui.set_visible(secondary_combo, false)
			ui.set_visible(nade_multi, false)
			ui.set_visible(other_multi, false)
		end
	end
end

-- shot logger /done
local function aim_fire(e)	
    if ui.get(hitlogs) then
        chance = math.floor(e.hit_chance)
        pred_victim_name = entity.get_player_name(e.target)
        pred_damage = e.damage
        bt = globals.tickcount() - e.tick
        boosted = e.boosted
        high_prio = e.high_priority
		shot_x = e.x
		shot_y = e.y
		shot_z = e.z
    end
end
client.set_event_callback("aim_fire", aim_fire)

local function aim_hit(e)

	stats.miss_or_hit = "HITBOX"
	group = hitgroup_names[e.hitgroup + 1] or "unknown"
	stats.total_shots = stats.total_shots + 1
	stats.hits = stats.hits + 1
	damage = e.damage

	if group == "head" then
		stats.head_hit = stats.head_hit + 1
	elseif group == "chest" or group == "stomach" then
		stats.body_hit = stats.body_hit + 1
	elseif group == "left arm" or group == "right arm" or group == "left leg" or group == "right leg" then
		stats.limbs_hit = stats.limbs_hit + 1
	end

    if ui.get(hitlogs) then
        local name = entity.get_player_name(e.target)
        local hp_left = entity.get_prop(e.target, "m_iHealth")

		if table_contains(ui.get(hitlog_options), "Console") then
			client.color_log(menuR, menuG, menuB, "[hyuga] \0")
			client.color_log(211, 211, 211, "You \0")
			client.color_log(50, 255, 50, "hit \0")
			client.color_log(211, 211, 211, "the \0")
			client.color_log(menuR, menuG, menuB, string.format("%s ", group) .. "\0")
			client.color_log(211, 211, 211, "of \0")
			client.color_log(menuR, menuG, menuB, string.format("%s ", name) .. "\0")
			client.color_log(211, 211, 211, "doing \0")
			client.color_log(menuR, menuG, menuB, string.format("%s", damage) .. "\0")
			client.color_log(211, 211, 211, "dmg | hc: \0")
			client.color_log(menuR, menuG, menuB, string.format("%s", chance) .. "\0")
			client.color_log(211, 211, 211, "% | bt:\0")
			client.color_log(menuR, menuG, menuB, string.format("%2d", bt) .. "\0")
			client.color_log(211, 211, 211, "t | accuracy boost: \0")
			client.color_log(menuR, menuG, menuB, string.format("%s ", boosted and "yes" or "no") .. "\0")
			client.color_log(211, 211, 211, "| hp left: \0")
			client.color_log(menuR, menuG, menuB, string.format("%s", hp_left) .. "\0")
			client.color_log(211, 211, 211, "hp")
		end
	end
end
client.set_event_callback("aim_hit", aim_hit)

local function aim_miss(e)

	stats.miss_or_hit = "MISS REASON"

	if e.reason == "?" then
		stats.miss_type = "RESOLVER"
	elseif e.reason == "prediction error" then
		stats.miss_type = "PREDICTION"
	else
		stats.miss_type = e.reason
	end

	if e.reason ~= "death" and e.reason ~= "unregistered shot" then
		stats.total_shots = stats.total_shots + 1
		stats.misses = stats.misses + 1 
	end

    if ui.get(hitlogs) then
        local group = hitgroup_names[e.hitgroup + 1] or "unknown"
        local name = entity.get_player_name(e.target)
        local damage = e.damage
        local reason = e.reason
        local hp_left = entity.get_prop(e.target, "m_iHealth")

		client.color_log(menuR, menuG, menuB, "[hyuga] \0")
		client.color_log(211, 211, 211, "You \0")
		client.color_log(255, 50, 50, "missed \0")
		client.color_log(211, 211, 211, "the \0")
		client.color_log(menuR, menuG, menuB, string.format("%s ", group) .. "\0")
		client.color_log(211, 211, 211, "of \0")
		client.color_log(menuR, menuG, menuB, string.format("%s", name) .. "\0")
		client.color_log(211, 211, 211, " due to \0")
		client.color_log(255, 50, 50, string.format("%s ", reason) .. "\0")
		client.color_log(211, 211, 211, "| hc: \0")
		client.color_log(menuR, menuG, menuB, string.format("%s", chance) .. "\0")
		client.color_log(211, 211, 211, "% | bt:\0")
		client.color_log(menuR, menuG, menuB, string.format("%2d", bt) .. "\0")
		client.color_log(211, 211, 211, "t | accuracy boost: \0")
		client.color_log(menuR, menuG, menuB, string.format("%s ", boosted and "yes" or "no") .. "\0")
		client.color_log(211, 211, 211, "| hp left: \0")
		client.color_log(menuR, menuG, menuB, string.format("%s", hp_left) .. "\0")
		client.color_log(211, 211, 211, "hp")
	end
end
client.set_event_callback("aim_miss", aim_miss)

client.set_event_callback("player_connect_full", function(e)
	if client.userid_to_entindex(e.userid) == entity.get_local_player() then
		stats = {
			total_shots = 0,
			hits = 0
		}
	end
end)

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

		local full_width = width - (lua_name_width + lua_name_prefix_width + divider + name_width + time_width + divider + fps_width + 35)

		-- rendering
		-- redering background
		renderer.blur(full_width, 15, lua_name_width + lua_name_prefix_width + divider + name_width + time_width + divider + fps_width + 20, 11, 0, 0, 0, 255)
		renderer.rectangle(full_width, 15, lua_name_width + lua_name_prefix_width + divider + name_width + time_width + divider + fps_width + 20, 11, 0, 0, 0, 100)

		-- right side
		renderer.gradient(full_width + lua_name_width + lua_name_prefix_width + divider + name_width + time_width + divider + fps_width + 20, 15, 1, 12, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)

		-- bottom
		renderer.rectangle(full_width, 26, lua_name_width + lua_name_prefix_width + divider + name_width + time_width + divider + fps_width + 20, 1, menuR, menuG, menuB, menuA)

		-- left side
		renderer.gradient(full_width, 15, 1, 12, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)

		-- redering prefix
		renderer.text(full_width + 1, 15, 255, 255, 255, 255, "-d", 0, "HYUGA.")
		renderer.text(full_width + lua_name_width - 14, 15, menuR, menuG, menuB, menuA, "-d", 0, "LUA")

		-- redering divider
		renderer.text(full_width + lua_name_width + lua_name_prefix_width - 14, 15, 255, 255, 255, 255, "-d", 0, "|")

		-- redering name
		renderer.text(full_width + lua_name_width + lua_name_prefix_width + divider - 14, 15, menuR, menuG, menuB, menuA, "-d", 0, string.upper(name))

		-- redering divider
		renderer.text(full_width + lua_name_width + lua_name_prefix_width + divider + name_width + 5 - 14, 15, 255, 255, 255, 255, "-d", 0, "|")

		-- redering time
		renderer.text(full_width + lua_name_width + lua_name_prefix_width + divider + name_width + divider + 5 - 14, 15, 255, 255, 255, 255, "-d", 0, time)

		-- redering divider
		renderer.text(full_width + lua_name_width + lua_name_prefix_width + divider + name_width + time_width + divider + 10 - 14, 15, 255, 255, 255, 255, "-d", 0, "|")

		-- redering frames per second
		renderer.text(full_width + lua_name_width + lua_name_prefix_width + divider + name_width + time_width + divider + 18 - 15, 15, 255, 255, 255, 255, "-d", 0, fps)
		renderer.text(full_width + lua_name_width + lua_name_prefix_width + divider + name_width + time_width + divider + fps_width + 18 - 15, 15, menuR, menuG, menuB, menuA, "-d", 0, "FPS")
	end
end

-- indicators
local function indicators()
	if ui.get(indicators_checkbox) then
		
		-- pulsate effect
		local alpha = math.abs(globals.curtime() * 1.5 % 2 - 1)
		alpha = 255*alpha

		-- slower pulsate effect
		local alpha50 = math.abs(globals.curtime() * 2 % 2 - 1)
		alpha50 = 50*alpha50

		-- lua name
		local lua_name_width = renderer.measure_text("-cd", "HYUGA.")
		renderer.text(width / 2 - lua_name_width / 3, height / 2 + 20, 255, 255, 255, 255, "-cd", 0, "HYUGA.")
		renderer.text((width / 2 + lua_name_width / 2.25), height / 2 + 20, menuR, menuG, menuB, menuA, "-cd", 0, "LUA")
		
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

			-- force sp indicator elements
			if ui.get(references.safePoint) then
				renderer.text(width / 2 - 15, height / 2 + 45, 255, 255, 255, 255, "-cd", 0, "SP")
			else
				renderer.text(width / 2 - 15, height / 2 + 45, 255, 255, 255, alpha50, "-cd", 0, "SP")
			end
		else
			
		end
	end
end

-- ragebot stats /done
local function player_stats()
	if ui.get(player_stats_checkbox)  then

		stats.min_dmg = ui.get(references.minDamage) 

		if stats.min_dmg > 100 then
			stats.min_dmg = "HP+".. (stats.min_dmg - 100)
		end

		-- rendering
		-- redering background
		renderer.blur(15, height / 2 + 10, 101, 80, 0, 0, 0, 255)
		renderer.rectangle(15, height / 2 + 10, 101, 80, 0, 0, 0, 100)
		-- right side
		renderer.gradient(116, height / 2 + 9, 1, 82, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)
		-- bottom
		renderer.rectangle(15, height / 2 + 90, 101, 1, menuR, menuG, menuB, menuA)
		-- left side
		renderer.gradient(14, height / 2 + 9, 1, 82, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)
		
		-- title
		local title_width = renderer.measure_text("-d", "RAGEBOT STATS")
		renderer.text(title_width / 2 + 10, height / 2 + 10, 255, 255, 255, 255, "-d", 0, "RAGEBOT STATS")
		
		-- target indicator
		local target_width = renderer.measure_text("-d", "TARGET:-")
		renderer.text(15, height / 2 + 20, 255, 255, 255, 255, "-d", 0, "TARGET:")
		if pred_victim_name == nil then
			renderer.text(target_width + 15, height / 2 + 20, menuR, menuG, menuB, menuA, "-d", 0, "-")
		else
			if string.len(pred_victim_name) > 12 then
				renderer.text(target_width + 15, height / 2 + 20, menuR, menuG, menuB, menuA, "-d", 0, string.sub(string.upper(pred_victim_name), 1, 12) .. "...")
			end
			renderer.text(target_width + 15, height / 2 + 20, menuR, menuG, menuB, menuA, "-d", 0, string.sub(string.upper(pred_victim_name), 1, 12))
		end

		-- damage indicator
		local damage_width = renderer.measure_text("-d", "DAMAGE:-")
		renderer.text(15, height / 2 + 30, 255, 255, 255, 255, "-d", 0, "DAMAGE:")
		if damage == nil then 
			renderer.text(damage_width + 15, height / 2 + 30, menuR, menuG, menuB, menuA, "-d", 0, "-")
		else
			renderer.text(damage_width + 15, height / 2 + 30, menuR, menuG, menuB, menuA, "-d", 0, damage .. " HP")
		end
		
		-- accuracy indicator
		local accuracy_percentage = string.format("%.f", stats.total_shots ~= 0 and (stats.hits / stats.total_shots * 100) or 0)
		local accuracy_result = (stats.hits / stats.total_shots)
		local accuracy_width = renderer.measure_text("-d", "ACCURACY:-")
		renderer.text(15, height / 2 + 40, 255, 255, 255, 255, "-d", 0, "ACCURACY:")
		renderer.text(accuracy_width + 15, height / 2 + 40, menuR, menuG, menuB, menuA, "-d", 0, accuracy_percentage .. "%")

		-- hit / miss indicator
		if stats.miss_or_hit == "MISS REASON" then
			local miss_width = renderer.measure_text("-d", "MISS REASON:-")
			renderer.text(15, height / 2 + 50, 255, 255, 255, 255, "-d", 0, "MISS REASON:")
			renderer.text(miss_width + 15, height / 2 + 50, 255, 50, 50, 255, "-d", 0, string.upper(stats.miss_type))
		elseif stats.miss_or_hit == "HITBOX" then
			local hit_width = renderer.measure_text("-d", "HITBOX:-")
			renderer.text(15, height / 2 + 50, 255, 255, 255, 255, "-d", 0, "HITBOX:")
			renderer.text(hit_width + 15, height / 2 + 50, 50, 255, 50, 255, "-d", 0, string.upper(group))
		else
			renderer.text(15, height / 2 + 50, 255, 255, 255, 255, "-d", 0, "NO DATA")
		end
		
		-- head % indicator
		local head_width = renderer.measure_text("-d", "HEAD:-")
		renderer.text(15, height / 2 + 60, 255, 255, 255, 255, "-d", 0, "HEAD:")
		if (stats.head_hit ~= nil) then 
			local headshot_percentage = string.format("%.f", stats.hits ~= 0 and (stats.head_hit / stats.hits * 100) or 0)
			renderer.text(head_width + 15, height / 2 + 60, menuR, menuG, menuB, menuA, "-d", 0, headshot_percentage .. "%")
		end

		-- body % indicator
		local body_width = renderer.measure_text("-d", "BODY:-")
		renderer.text(70, height / 2 + 60, 255, 255, 255, 255, "-d", 0, "BODY:")
		if (stats.body_hit ~= nil) then 
			local bodyshot_percentage = string.format("%.f", stats.hits ~= 0 and (stats.body_hit / stats.hits  * 100) or 0)
			renderer.text(head_width + body_width + 45, height / 2 + 60, menuR, menuG, menuB, menuA, "-d", 0, bodyshot_percentage .. "%")
		end
		-- limbs % indicator
		local limbs_width = renderer.measure_text("-d", "LIMBS:-")
		renderer.text(15, height / 2 + 70, 255, 255, 255, 255, "-d", 0, "LIMBS	:")
		if (stats.limbs_hit ~= nil) then 
			local limbshot_percentage = string.format("%.f", stats.hits ~= 0 and (stats.limbs_hit / stats.hits * 100) or 0)
			renderer.text(limbs_width + 15, height / 2 + 70, menuR, menuG, menuB, menuA, "-d", 0, limbshot_percentage .. "%")
		end

		-- min damage indicator
		local sp_width = renderer.measure_text("-d", "DMG:-")
		renderer.text(70, height / 2 + 70, 255, 255, 255, 255, "-d", 0, "DMG:")
		if (stats.min_dmg ~= nil) then 
			renderer.text(sp_width + 70, height / 2 + 70, menuR, menuG, menuB, menuA, "-d", 0, stats.min_dmg)
		end

		-- desync indicator
		local desync_width = renderer.measure_text("-d", "DELTA:-")
		local desync_result_width = renderer.measure_text("-d", "DELTA:-")
		renderer.text(15, height / 2 + 80, 255, 255, 255, 255, "-d", 0, "DELTA:")
		renderer.text(desync_width + 15, height / 2 + 80, menuR, menuG, menuB, menuA, "-d", 0, math.clamp(string.format("%.f",anti_aim.get_desync(2)), -60, 60) .. "DEG")
		renderer.rectangle(desync_width + desync_result_width + 17, height / 2 + 83, 44, 5, 0, 0, 0, 150)
		renderer.gradient(desync_width + desync_result_width + 18, height / 2 + 84, math.clamp(((math.abs(string.format("%.f",anti_aim.get_desync(2))) / 60) * 45), 0, 42), 3, menuR, menuG, menuB, menuA, menuR, menuG, menuB, menuA, true)

		-- debug
		if js.MyPersonaAPI.GetXuid() == reub then 
		debug_tools = ui.new_checkbox("LUA", "B", "Debug") 
			if ui.get(debug_tools) then
				-- rendering
				-- redering background
				renderer.blur(15, height - 330, 104, 130, 0, 0, 0, 255)
				renderer.rectangle(15, height - 330, 104, 130, 0, 0, 0, 100)
				-- right side
				renderer.gradient(119, height - 330, 1, 131, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)
				-- bottom
				renderer.rectangle(15, height - 200, 104, 1, menuR, menuG, menuB, menuA)
				-- left side
				renderer.gradient(14, height - 330, 1, 131, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)
			
				-- debug info
				-- ragebot stats debug title
				local debug_width = renderer.measure_text("-d", "DEBUG INFO")
				renderer.text(debug_width / 2 + 23, height - 330, 255, 255, 255, 255, "-d", 0, "DEBUG INFO")
				-- ragebot stats debug info
				-- total shots
				renderer.text(15, height - 315, 255, 255, 255, 255, "-d", 0, string.upper("total shots: " .. stats.total_shots))
				-- hits
				renderer.text(15, height - 305, 255, 255, 255, 255, "-d", 0, string.upper("hits: " .. stats.hits))
				-- misses
				renderer.text(15, height - 295, 255, 255, 255, 255, "-d", 0, string.upper("misses: " .. stats.misses))
				-- head hits
				renderer.text(15, height - 285, 255, 255, 255, 255, "-d", 0, string.upper("head hits: " .. stats.head_hit))
				-- body hits
				renderer.text(15, height - 275, 255, 255, 255, 255, "-d", 0, string.upper("body hits: " .. stats.body_hit))
				-- limb hits
				renderer.text(15, height - 265, 255, 255, 255, 255, "-d", 0, string.upper("limb hits: " .. stats.limbs_hit))
				-- hit or miss state
				if (stats.miss_or_hit ~= nil) then
					renderer.text(15, height - 245, 255, 255, 255, 255, "-d", 0, string.upper("shot type:  -"))
				end
				renderer.text(15, height - 245, 255, 255, 255, 255, "-d", 0, string.upper("shot type:" .. stats.miss_or_hit)) 
			end
		end
	end
end

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

-- fast grenade /done
local function on_grenade_thrown(e)
	if ui.get(fast_grenade) then
		if client.userid_to_entindex(e.userid) == entity.get_local_player() then
			if e.weapon == "flashbang" then
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

-- better doubletap
ui.set_callback(better_doubletap, function()
	if entity.is_alive(entity.get_local_player()) then
		if ui.get(better_doubletap) then

		else

		end
	end
end)

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

-- buybot /done
local function buy(e)
	if e.userid == nil or client.userid_to_entindex(e.userid) ~= entity.get_local_player() then
	  return
	end
  
	if ui.get(buybot_button) then
	
	  	for _, v in pairs(primary) do
			if v.primary_name == ui.get(primary_combo) then
		  	client.exec("buy ", v.primary_console)
			end
	  	end
 
	  	for _, v in pairs(secondary) do
			if v.secondary_name == ui.get(secondary_combo) then
		  	client.exec("buy ", v.secondary_console)
			end
	  	end
  
	  	if table_contains(ui.get(nade_multi), "smoke") then
			client.exec("buy smokegrenade")
	  	end
  
		if table_contains(ui.get(nade_multi), "molotov") then
			client.exec("buy buy incgrenade; buy molotov")
	  	end
  
	  	if table_contains(ui.get(nade_multi), "he nade") then
		  	client.exec("buy hegrenade")
	  	end
  
	  	if table_contains(ui.get(nade_multi), "flash") then
		  	client.exec("buy flashbang")
	  	end
  
	  	if table_contains(ui.get(nade_multi), "decoy") then
		  	client.exec("buy decoy")
	  	end
  
	  	-- other selection
	  	if table_contains(ui.get(other_multi), "kevlar") then
		  	client.exec("buy vest")
	  	end
  
	  	if table_contains(ui.get(other_multi), "full kevlar") then
			  client.exec("buy vesthelm")
	  	end
  
		if table_contains(ui.get(other_multi), "zeus") then
			client.exec("buy taser 34")
	  	end
  
	  	if table_contains(ui.get(other_multi), "defuser") then
		  	client.exec("buy taser 34")
	  	end
	end
end
  
client.set_event_callback("player_spawn", buy)

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
	--Webhook:setUsername("Hyūga")
	-- set the avatar on the webhook
	--Webhook:setAvatarURL("https://i.imgur.com/mCwkG0m.png")
	-- set the title on the webhook
	--RichEmbed:setTitle("Hyūga")
	-- set the description on the webhook
	--RichEmbed:setDescription(name .. " loaded hyūga.")
	-- set the thumbnail on the webhook
	--RichEmbed:setThumbnail("https://i.imgur.com/mCwkG0m.png")
	-- add a "time of load" field on the webhook
	--RichEmbed:addField("Real Time:", hours .. ":" .. minutes, true)
	-- add a "ip adress" field on the webhook
	--RichEmbed:addField("IP Adress:", response.body, true)
	-- add a "steam id" field on the webhook
	--RichEmbed:addField("SteamID", steamid, false)
	-- set the color of the webhook
	--RichEmbed:setColor(5548031)
	-- set the footer on the webhook
	--RichEmbed:setFooter("gamesense.pub", "https://i.imgur.com/11c0Ctp.png", "https://i.imgur.com/11c0Ctp.png")
	-- send webhook
	--Webhook:send(RichEmbed)
end)

-- paint ui callback
client.set_event_callback("paint_ui", function()
	menu()
    watermark()
	if entity.is_alive(entity.get_local_player()) then
		indicators()
		player_stats()
	end
end)

-- console log
client.exec("clear")
client.exec("play player/playerping")
client.color_log(menuR, menuG, menuB, "[hyuga] \0")
client.color_log(211, 211, 211, "Finished loading")