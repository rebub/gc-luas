-- require
local ffi = require "ffi"
local easing = require "gamesense/easing"
local images = require "gamesense/images"
local anti_aim = require "gamesense/antiaim_funcs"
local csgo_weapons = require "gamesense/csgo_weapons"

-- ffi 
local def = ffi.cdef([[ 
	typedef void***(__thiscall* FindHudElement_t)(void*, const char*); 
	typedef struct { 
		char pad[0x58];
		bool isChatOpen;
	} CCSGO_HudChat;
    ]])

-- signatures
local signature_gHud = "\xB9\xCC\xCC\xCC\xCC\x88\x46\x09"
local signature_FindElement = "\x55\x8B\xEC\x53\x8B\x5D\x08\x56\x57\x8B\xF9\x33\xF6\x39\x77\x28"

-- is chat open variables
local match = client.find_signature("client.dll", signature_gHud) or error("sig1 not found")
local char_match = ffi.cast("char*", match) + 1
local hud = ffi.cast("void**", char_match)[0] or error("hud is nil")
local match = client.find_signature("client.dll", signature_FindElement) or error("FindHudElement not found")
local find_hud_element = ffi.cast("FindHudElement_t", match)
local hudElement = find_hud_element(hud, "CCSGO_HudChat") or error("CCSGO_HudChat not found")
local hudChat
if (hudElement ~= nil) then
	hudChat = ffi.cast("CCSGO_HudChat*", hudElement)
end

-- global variables
local reub = 76561198384716464
local width, height = client.screen_size()
local FileName = string.format('%s.lua', _NAME)
local key_states = {
    [0] = "Always on",
    [1] = "On hotkey",
    [2] = "Toggle",
    [3] = "Off hotkey"
}

-- panorama 
local js = panorama.open()
local mouse_position_x, mouse_position_y = ui.mouse_position()
local name, steamid = js.MyPersonaAPI.GetName() , js.MyPersonaAPI.GetXuid()

-- menu variables
local menu_color = ui.reference("Misc", "Settings", "Menu color")
local qpm, qpcolor = ui.reference("RAGE", "Other", "Quick peek assist mode")
local oofc, oofcolor = ui.reference("VISUALS", "Player ESP", "Out of fov arrow")
local menuR, menuG, menuB, menuA = ui.get(ui.reference("Misc", "Settings", "Menu color"))

-- clantag variables
local clantags = {"hyūga"}
local clantag_prev

-- fast grenade variables
local switch_to_flash_at = nil
local next_command_at = nil

-- indicator variables /dt
local doubletap_charge = 0

-- spectator list variables
local spec_list_w, spec_list_h = 101, 80

-- player stats variables
local player_stats_w, player_stats_h = 101, 80
local stats = {
	total_shots = 0,
	hits = 0,
	misses = 0,
	miss_type = "",
	head_hit = 0,
	body_hit = 0,
	limb_hit = 0,
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

-- shot logger variables
local hitgroup_names = {"body", "head", "chest", "stomach", "left arm", "right arm", "left leg", "right leg", "neck", "unknown", "gear"}

-- bomb timer variables
local bomb_info = {
    site = "unknown",
    explode_time = 0,
    time_to_explode = 0,
    defuse_time = 0,
    time_to_defuse = 0,
    alpha = 0,
    alpha_text = 0,
    defusing = false,
    defused = false,
    alpha_defuse = 0,
    alpha_text_defuse = 0,
}

-- menu elements (lua, a tab)
-- hud elements
ui.new_label("LUA", "A", "Hud Elements")
watermark_checkbox = ui.new_checkbox("LUA", "A", "Watermark")
indicators_checkbox = ui.new_checkbox("LUA", "A", "Indicators")
player_spectators_checkbox = ui.new_checkbox("LUA", "A", "Spectators")
player_stats_checkbox = ui.new_checkbox("LUA", "A", "Player Stats")
bomb_checkbox = ui.new_checkbox("LUA", "A", "Bomb Timer")

--divider
ui.new_label("LUA", "A", " ")
-- improvements
ui.new_label("LUA", "A", "Improvements")
fast_grenade = ui.new_checkbox("LUA", "A", "Fast Grenade")
better_doubletap = ui.new_checkbox("LUA", "A", "Better Doubletap")
disable_exploits = ui.new_checkbox("LUA", "A", "Conditional Exploits")
--divider
ui.new_label("LUA", "A", " ")
-- misc elements
ui.new_label("LUA", "A", "Misc Elements")
hitlogs = ui.new_checkbox("LUA", "A", "Hitlog")
clantag_checkbox = ui.new_checkbox("LUA", "A", "Clantag")
set_console = ui.new_checkbox("LUA", "A", "Filter console") 
auto_dc = ui.new_checkbox("LUA", "A", "Auto Disconnect") 
first_person_nade = ui.new_checkbox("LUA", "A", "First Person Nade") 
--divider
ui.new_label("LUA", "A", " ")

-- menu elements (lua, b tab)
ui.new_label("LUA", "B", "Other Elements")
-- rainbow element
rainbow_mode = ui.new_checkbox("LUA", "B", "Rainbow Mode")
-- match crosshair color
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
--divider
ui.new_label("LUA", "B", " ")
-- buybot elements
ui.new_label("LUA", "B", "Position Sliders")
position_sliders = ui.new_checkbox("LUA", "B", "Enable Position Sliders")
-- cheat stats elements
player_stats_x = ui.new_slider("LUA", "B", "Horizontal Control - Player Stats List", 0, width, 15, true, "px", 1)
player_stats_y = ui.new_slider("LUA", "B", "Vertical Control - Player Stats List", 0, height, 540, true, "px", 1)
-- spec list position slider elements
spec_list_x = ui.new_slider("LUA", "B", "Horizontal Control - Spectator List", 0, width, 15, true, "px", 1)
spec_list_y = ui.new_slider("LUA", "B", "Vertical Control - Spectator List", 0, height, 680, true, "px", 1)
--divider
ui.new_label("LUA", "B", " ")
-- debug element
ui.new_label("LUA", "B", "Debug Tools")
debug_tools = ui.new_checkbox("LUA", "B", "Debug") 

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
	-- legit bot
	aimbot = { ui.reference("LEGIT", "Aimbot", "Enabled") } ,
	aimbot_fov = ui.reference("LEGIT", "Aimbot", "Maximum FOV"),
	trigerbot = { ui.reference("LEGIT", "Triggerbot", "Enabled") } 
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

-- frames per second function
local function accumulate_fps()
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

-- doubletap charge function
local function doubletap_charged()
    -- Make sure we have doubletap enabled, are holding our doubletap key & we aren't fakeducking.
    if not ui.get(references.doubleTap[1]) or not ui.get(references.doubleTap[2]) or ui.get(references.fakeDuck) then return false end

    -- Sanity checks on local player (since paint & a few other events run even when dead).
    if not entity.is_alive(entity.get_local_player()) or entity.get_local_player() == nil then return end

    -- Get our local players weapon.
    local weapon = entity.get_prop(entity.get_local_player(), "m_hActiveWeapon")

    -- Make sure that it is valid.
    if weapon == nil then return false end

    -- Basic definitions used to calculate if we have recently shot or swapped weapons.
    local next_attack = entity.get_prop(entity.get_local_player(), "m_flNextAttack") + 0.25
	local next_primary_attack_5less = entity.get_prop(weapon, "m_flNextPrimaryAttack")
	
	if next_primary_attack_5less == nil then return end
	
    local next_primary_attack = next_primary_attack_5less + 0.5

    -- Make sure both values are valid.
    if next_attack == nil or next_primary_attack == nil then return false end

    -- Return if both are under 0 meaning our doubletap is charged / we can fire (you can also use these values as a 2nd return parameter to get the charge %).
    return next_attack - globals.curtime() < 0 and next_primary_attack - globals.curtime() < 0
end

-- get weapon class
local function get_wpn_class(ent)
    return entity.get_classname(entity.get_player_weapon(ent))
end

-- rgb function
local function hsv_to_rgb(h, s, v, a)
    local r, g, b

    local i = math.floor(h * 6);
    local f = h * 6 - i;
    local p = v * (1 - s);
    local q = v * (1 - f * s);
    local t = v * (1 - (1 - f) * s);

    i = i % 6

    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
  
    return r * 255, g * 255, b * 255, a * 255
end

local function func_rgb_rainbowize(frequency, rgb_split_ratio)
    local r, g, b, a = hsv_to_rgb(globals.realtime() * frequency, 0.5, 1, 1)

    r = r * rgb_split_ratio
    g = g * rgb_split_ratio
    b = b * rgb_split_ratio
	a = 255

    return r, g, b, a
end

-- paint
-- menu stuff /done
local function menu()
		-- color
		if ui.get(rainbow_mode) then
			menuR, menuG, menuB, menuA = func_rgb_rainbowize(0.1, 1)
			-- menu color
			ui.set(menu_color, menuR, menuG, menuB, menuA)
			-- quick peek assist
			ui.set(qpcolor, menuR, menuG, menuB, menuA)
			-- oof arrows
			ui.set(oofcolor, menuR, menuG, menuB, menuA)
		else
			menuR, menuG, menuB, menuA = ui.get(menu_color)
		end

	if ui.is_menu_open() then

		-- mouse position
		mouse_position_x, mouse_position_y = ui.mouse_position()

		-- menu position & size
		local mx, my = ui.menu_position()
		
		--menu size
		local mw, mh = ui.menu_size()
				
		-- left side
		renderer.gradient(mx - 1, my + 1, 1, mh, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)
		-- bottom side
		renderer.gradient(mx, my + mh, mw, 1, menuR, menuG, menuB, menuA, menuR, menuG, menuB, menuA, true)
		-- right side
		renderer.gradient(mx + mw, my + 1, 1, mh, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)

		-- crosshair /done
		client.exec("cl_crosshaircolor_r ", menuR, "; cl_crosshaircolor_g ", menuG, "; cl_crosshaircolor_b ", menuB)

		-- legit fov viewer /done
		if not ui.get(references.enabled_rage) then
			if entity.is_alive(entity.get_local_player()) then
				renderer.circle_outline(width / 2, height / 2, menuR, menuG, menuB, menuA, ui.get(references.aimbot_fov), 0, 1, 1)
				renderer.circle(width / 2, height / 2, menuR, menuG, menuB, 50, ui.get(references.aimbot_fov), 0, 1)
			end
		end

		-- buybot menu setup
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

		-- position sliders checkbox setup
		local pos_checkbox_check = false
		if not ui.get(player_stats_checkbox) and not ui.get(player_spectators_checkbox) then 
			ui.set(position_sliders, false)
			pos_checkbox_check = true
		else
			if pos_checkbox_check == true then
				pos_checkbox_check = false
				ui.set(position_sliders, true)
			end
		end

		-- player stats position sliders setup
		if ui.get(player_stats_checkbox) then 
			if ui.get(position_sliders) then
				ui.set_visible(player_stats_x, true)
				ui.set_visible(player_stats_y, true)
			else
				ui.set_visible(player_stats_x, false)
				ui.set_visible(player_stats_y, false)
			end
		else
			ui.set_visible(player_stats_x, false)
			ui.set_visible(player_stats_y, false)
		end

		-- spectator list position sliders setup
		if ui.get(player_spectators_checkbox) then
			if ui.get(position_sliders) then
				ui.set_visible(spec_list_x, true)
				ui.set_visible(spec_list_y, true)
			else
				ui.set_visible(spec_list_x, false)
				ui.set_visible(spec_list_y, false)
			end
		else
			ui.set_visible(spec_list_x, false)
			ui.set_visible(spec_list_y, false)
		end

		-- spectator removal
		if ui.get(player_spectators_checkbox) then
			if ui.reference("VISUALS", "Other ESP", "Spectators") then
				ui.set(ui.reference("VISUALS", "Other ESP", "Spectators"), false)
			end
			ui.set_visible(ui.reference("VISUALS", "Other ESP", "Spectators"), false)
		else
			ui.set_visible(ui.reference("VISUALS", "Other ESP", "Spectators"), true)
		end
	end
end

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

	if client.key_state(0x01) and (mouse_position_y > ui.get(spec_list_y) and mouse_position_y < ui.get(spec_list_y) + spec_list_h) and (mouse_position_x > ui.get(spec_list_x) and mouse_position_x < ui.get(spec_list_x) + spec_list_w) then
		ui.set(spec_list_x, math.clamp(mouse_position_x - 50, 0, width - 102))
	end	

end

-- indicators /done
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
				
				-- dt indicator elements
				local weapon = entity.get_prop(entity.get_local_player(), "m_hActiveWeapon")
				local next_attack = entity.get_prop(entity.get_local_player(), "m_flNextAttack") + 0.25
				local next_primary_attack_5less = entity.get_prop(weapon, "m_flNextPrimaryAttack")
				
				if next_primary_attack_5less == nil then return end
				
				local next_primary_attack = next_primary_attack_5less + 0.5
				
				if next_primary_attack - globals.curtime() < 0 and next_attack - globals.curtime() < 0 then
					charge = 0
				else
					charge = next_primary_attack - globals.curtime()
				end
				
				local dt_charge = math.abs((charge * 10/6) - 1)


				doubletap_charge = easing.linear(dt_charge, 0, 1, 1)	

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
			local duck_amt = entity.get_prop(entity.get_local_player(), "m_flDuckAmount")
			renderer.rectangle(width / 2 - 10, height / 2 + 32, 33, 7, 0, 0, 0, 125)
			renderer.rectangle(width / 2 - 9, height / 2 + 33, duck_amt / 1 * 31, 5, menuR, menuG, menuB, menuA)
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

-- player stats /done
local function player_stats()
	if ui.get(player_stats_checkbox)  then

		-- debug
		if ui.get(debug_tools) then
					if js.MyPersonaAPI.GetXuid() == reub then 
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
		
						-- mouse indicator
						renderer.rectangle(mouse_position_x - 5, mouse_position_y - 5, 10, 10, 211, 50, 50, 100)
						
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
						renderer.text(15, height - 265, 255, 255, 255, 255, "-d", 0, string.upper("limb hits: " .. stats.limb_hit))
						-- hit or miss state
						if (stats.miss_or_hit ~= nil) then
							renderer.text(15, height - 245, 255, 255, 255, 255, "-d", 0, string.upper("shot type:  -"))
						end
						renderer.text(15, height - 245, 255, 255, 255, 255, "-d", 0, string.upper("shot type:" .. stats.miss_or_hit)) 
					end
		end

		if ui.get(references.enabled_rage) then
			stats.min_dmg = ui.get(references.minDamage) 

			if stats.min_dmg > 100 then
				stats.min_dmg = "HP+".. (stats.min_dmg - 100)
			end

			-- rendering
			-- redering background
			renderer.blur(ui.get(player_stats_x), ui.get(player_stats_y), player_stats_w, player_stats_h, 0, 0, 0, 255)
			renderer.rectangle(ui.get(player_stats_x), ui.get(player_stats_y), player_stats_w, player_stats_h, 0, 0, 0, 100)
			-- right side
			renderer.gradient((ui.get(player_stats_x) + 101), ui.get(player_stats_y), 1, 81, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)
			-- bottom
			renderer.rectangle(ui.get(player_stats_x), ui.get(player_stats_y) + 80, 101, 1, menuR, menuG, menuB, menuA)
			-- left side
			renderer.gradient(ui.get(player_stats_x), ui.get(player_stats_y), 1, 81, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)
			
			-- title
			local title_width = renderer.measure_text("-d", "PLAYER STATS")
			renderer.text(ui.get(player_stats_x) + title_width / 2.2, ui.get(player_stats_y), 255, 255, 255, 255, "-d", 0, "PLAYER STATS")
			-- target indicator
			local target_width = renderer.measure_text("-d", "TARGET:-")
			renderer.text(ui.get(player_stats_x), ui.get(player_stats_y) + 10, 255, 255, 255, 255, "-d", 0, "TARGET:")
			if pred_victim_name == nil then
				renderer.text(ui.get(player_stats_x) + target_width, ui.get(player_stats_y) + 10, menuR, menuG, menuB, menuA, "-d", 0, "-")
			else
				if string.len(pred_victim_name) > 12 then
					renderer.text(ui.get(player_stats_x) + target_width, ui.get(player_stats_y) + 10, menuR, menuG, menuB, menuA, "-d", 0, string.sub(string.upper(pred_victim_name), 1, 12) .. "...")
				end
				renderer.text(ui.get(player_stats_x) + target_width, ui.get(player_stats_y) + 10, menuR, menuG, menuB, menuA, "-d", 0, string.sub(string.upper(pred_victim_name), 1, 12))
			end
			-- damage indicator
			local damage_width = renderer.measure_text("-d", "DAMAGE:-")
			renderer.text(ui.get(player_stats_x), ui.get(player_stats_y) + 20, 255, 255, 255, 255, "-d", 0, "DAMAGE:")
			if damage == nil then 
				renderer.text(ui.get(player_stats_x) + damage_width, ui.get(player_stats_y) + 20, menuR, menuG, menuB, menuA, "-d", 0, "-")
			else
				renderer.text(ui.get(player_stats_x) + damage_width, ui.get(player_stats_y) + 20, menuR, menuG, menuB, menuA, "-d", 0, damage .. " HP")
			end
			-- accuracy indicator
			local accuracy_percentage = string.format("%.f", stats.total_shots ~= 0 and (stats.hits / stats.total_shots * 100) or 0)
			local accuracy_result = (stats.hits / stats.total_shots)
			local accuracy_width = renderer.measure_text("-d", "ACCURACY:-")
			renderer.text(ui.get(player_stats_x), ui.get(player_stats_y) + 30, 255, 255, 255, 255, "-d", 0, "ACCURACY:")
			renderer.text(ui.get(player_stats_x) + accuracy_width, ui.get(player_stats_y) + 30, menuR, menuG, menuB, menuA, "-d", 0, accuracy_percentage .. "%")
			-- hit / miss indicator
			if stats.miss_or_hit == "MISS REASON" then
				local miss_width = renderer.measure_text("-d", "MISS REASON:-")
				renderer.text(ui.get(player_stats_x), ui.get(player_stats_y) + 40, 255, 255, 255, 255, "-d", 0, "MISS REASON:")
				renderer.text(ui.get(player_stats_x) + miss_width, ui.get(player_stats_y) + 40, 255, 50, 50, 255, "-d", 0, string.upper(stats.miss_type))
			elseif stats.miss_or_hit == "HITBOX" then
				local hit_width = renderer.measure_text("-d", "HITBOX:-")
				renderer.text(ui.get(player_stats_x), ui.get(player_stats_y) + 40, 255, 255, 255, 255, "-d", 0, "HITBOX:")
				renderer.text(ui.get(player_stats_x) + hit_width, ui.get(player_stats_y) + 40, 50, 255, 50, 255, "-d", 0, string.upper(group))
			else
				renderer.text(ui.get(player_stats_x), ui.get(player_stats_y) + 40, 255, 255, 255, 255, "-d", 0, "NO DATA")
			end
			-- head % indicator
			local head_width = renderer.measure_text("-d", "HEAD:-")
			renderer.text(ui.get(player_stats_x), ui.get(player_stats_y) + 50, 255, 255, 255, 255, "-d", 0, "HEAD:")
			if (stats.head_hit ~= nil) then 
				local headshot_percentage = string.format("%.f", stats.hits ~= 0 and (stats.head_hit / stats.hits * 100) or 0)
				renderer.text(ui.get(player_stats_x) + head_width, ui.get(player_stats_y) + 50, menuR, menuG, menuB, menuA, "-d", 0, headshot_percentage .. "%")
			end
			-- body % indicator
			local body_width = renderer.measure_text("-d", "BODY:-")
			renderer.text(ui.get(player_stats_x) + 55, ui.get(player_stats_y) + 50, 255, 255, 255, 255, "-d", 0, "BODY:")
			if (stats.body_hit ~= nil) then 
				local bodyshot_percentage = string.format("%.f", stats.hits ~= 0 and (stats.body_hit / stats.hits  * 100) or 0)
				renderer.text(ui.get(player_stats_x) + head_width + body_width + 31, ui.get(player_stats_y) + 50, menuR, menuG, menuB, menuA, "-d", 0, bodyshot_percentage .. "%")
			end
			-- limbs % indicator
			local limbs_width = renderer.measure_text("-d", "LIMBS:-")
			renderer.text(ui.get(player_stats_x), ui.get(player_stats_y) + 60, 255, 255, 255, 255, "-d", 0, "LIMBS	:")
			if (stats.limb_hit ~= nil) then 
				local limbshot_percentage = string.format("%.f", stats.hits ~= 0 and (stats.limb_hit / stats.hits * 100) or 0)
				renderer.text(ui.get(player_stats_x) + limbs_width, ui.get(player_stats_y) + 60, menuR, menuG, menuB, menuA, "-d", 0, limbshot_percentage .. "%")
			end
			-- min damage indicator
			local dmg_width = renderer.measure_text("-d", "DMG:-")
			renderer.text(ui.get(player_stats_x) + 55, ui.get(player_stats_y) + 60, 255, 255, 255, 255, "-d", 0, "DMG:")
			if (stats.min_dmg ~= nil) then 
				renderer.text(ui.get(player_stats_x) + dmg_width + 55, ui.get(player_stats_y) + 60, menuR, menuG, menuB, menuA, "-d", 0, stats.min_dmg)
			end
			-- desync indicator
			local desync_width = renderer.measure_text("-d", "DELTA:-")
			local desync_result_width = renderer.measure_text("-d", "DELTA:-")
			renderer.text(ui.get(player_stats_x), ui.get(player_stats_y) + 70, 255, 255, 255, 255, "-d", 0, "DELTA:")
			renderer.text(ui.get(player_stats_x) + desync_width, ui.get(player_stats_y) + 70, menuR, menuG, menuB, menuA, "-d", 0, math.clamp(string.format("%.f",anti_aim.get_desync(2)), -60, 60) .. "DEG")
			renderer.rectangle(ui.get(player_stats_x) + desync_width + desync_result_width + 2, ui.get(player_stats_y) + 73, 40, 5, 0, 0, 0, 150)
			renderer.gradient(ui.get(player_stats_x) + desync_width + desync_result_width + 3, ui.get(player_stats_y) + 74, math.clamp(((math.abs(string.format("%.f",anti_aim.get_desync(2))) / 60) * 40), 0, 38), 3, menuR, menuG, menuB, menuA, menuR, menuG, menuB, menuA, true)
		end

		if ui.get(references.aimbot[1]) and not ui.get(references.enabled_rage) then
			-- variables
			local playerresource = entity.get_all("CCSPlayerResource")[1]
			-- rendering
			-- redering background
			renderer.blur(ui.get(player_stats_x), ui.get(player_stats_y), 101, 60, 0, 0, 0, 255)
			renderer.rectangle(ui.get(player_stats_x), ui.get(player_stats_y), 101, 60, 0, 0, 0, 100)
			-- right side
			renderer.gradient((ui.get(player_stats_x) + 101), ui.get(player_stats_y), 1, 61, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)
			-- bottom
			renderer.rectangle(ui.get(player_stats_x), ui.get(player_stats_y) + 60, 101, 1, menuR, menuG, menuB, menuA)
			-- left side
			renderer.gradient(ui.get(player_stats_x), ui.get(player_stats_y), 1, 61, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)

			-- title
			local title_width = renderer.measure_text("-d", "PLAYER STATS")
			renderer.text(ui.get(player_stats_x) + title_width / 2.2, ui.get(player_stats_y), 255, 255, 255, 255, "-d", 0, "PLAYER STATS")
			-- aimbot indicator
			local aimbot_width = renderer.measure_text("-d", "AIMBOT:-")
			renderer.text(ui.get(player_stats_x), ui.get(player_stats_y) + 10, 255, 255, 255, 255, "-d", 0, "AIMBOT:")
			if ui.get(references.aimbot[1]) and ui.get(references.aimbot[2]) then
				local aimbot = { ui.get(references.aimbot[2]) }
				if key_states[aimbot[2]] == "Always on" then
					renderer.text(ui.get(player_stats_x) + aimbot_width, ui.get(player_stats_y) + 10, menuR, menuG, menuB, menuA, "-d", 0, "ON  [ALWAYS]")
				elseif key_states[aimbot[2]] == "On hotkey" then
					renderer.text(ui.get(player_stats_x) + aimbot_width, ui.get(player_stats_y) + 10, menuR, menuG, menuB, menuA, "-d", 0, "ON  [HOLD]")
				elseif key_states[aimbot[2]] == "Toggle" then
					renderer.text(ui.get(player_stats_x) + aimbot_width, ui.get(player_stats_y) + 10, menuR, menuG, menuB, menuA, "-d", 0, "ON  [TOGGLE]")
				else
					renderer.text(ui.get(player_stats_x) + aimbot_width, ui.get(player_stats_y) + 10, menuR, menuG, menuB, menuA, "-d", 0, "ON  [OFF]")
				end
			else
				renderer.text(ui.get(player_stats_x) + aimbot_width, ui.get(player_stats_y) + 10, 211, 50, 50, 255, "-d", 0, "OFF")
			end
			-- trigger indicator
			local trigger_width = renderer.measure_text("-d", "TRIGGERBOT:-")
			renderer.text(ui.get(player_stats_x), ui.get(player_stats_y) + 20, 255, 255, 255, 255, "-d", 0, "TRIGGERBOT:")
			if ui.get(references.trigerbot[1]) and ui.get(references.trigerbot[2]) then
				local triggerbot = { ui.get(references.trigerbot[2]) }
				if key_states[triggerbot[2]] == "Always on" then
					renderer.text(ui.get(player_stats_x) + trigger_width, ui.get(player_stats_y) + 20, menuR, menuG, menuB, menuA, "-d", 0, "ON  [ALWAYS]")
				elseif key_states[triggerbot[2]] == "On hotkey" then
					renderer.text(ui.get(player_stats_x) + trigger_width, ui.get(player_stats_y) + 20, menuR, menuG, menuB, menuA, "-d", 0, "ON  [HOLD]")
				elseif key_states[triggerbot[2]] == "Toggle" then
					renderer.text(ui.get(player_stats_x) + trigger_width, ui.get(player_stats_y) + 20, menuR, menuG, menuB, menuA, "-d", 0, "ON  [TOGGLE]")
				else
					renderer.text(ui.get(player_stats_x) + trigger_width, ui.get(player_stats_y) + 20, menuR, menuG, menuB, menuA, "-d", 0, "ON  [OFF]")
				end
			else
				renderer.text(ui.get(player_stats_x) + trigger_width, ui.get(player_stats_y) + 20, 211, 50, 50, 255, "-d", 0, "OFF")
			end
			-- speed indicator
			local speed_width = renderer.measure_text("-d", "SPEED:-")
			local vx, vy = entity.get_prop(entity.get_local_player(), "m_vecVelocity")
			local velocity = math.floor(math.min(10000, math.sqrt(vx^2 + vy^2)) + 0.5)
			renderer.text(ui.get(player_stats_x), ui.get(player_stats_y) + 30, 255, 255, 255, 255, "-d", 0, "SPEED:")
			renderer.text(ui.get(player_stats_x) + speed_width, ui.get(player_stats_y) + 30, menuR, menuG, menuB, menuA, "-d", 0, velocity .. " UNITS")
			-- backtrack indicator
			local backtrack_width = renderer.measure_text("-d", "BACKTRACK:-")
			renderer.text(ui.get(player_stats_x), ui.get(player_stats_y) + 40, 255, 255, 255, 255, "-d", 0, "BACKTRACK:")
			if ui.get(ui.reference("LEGIT", "Other", "Accuracy boost range")) then
				renderer.text(ui.get(player_stats_x) + backtrack_width, ui.get(player_stats_y) + 40, menuR, menuG, menuB, menuA, "-d", 0, ui.get(ui.reference("LEGIT", "Other", "Accuracy boost range")) .. " TICKS")
			end
			-- kills
			local m_iKills = entity.get_prop(playerresource, "m_iKills", entity.get_local_player()) 
			local legit_kills_width = renderer.measure_text("-d", "KILLS:-")
			renderer.text(ui.get(player_stats_x), ui.get(player_stats_y) + 50, 255, 255, 255, 255, "-d", 0, "KILLS:")
			renderer.text(ui.get(player_stats_x) + legit_kills_width, ui.get(player_stats_y) + 50, menuR, menuG, menuB, menuA, "-d", 0, m_iKills)
			-- deaths
			local m_iDeaths = entity.get_prop(playerresource, "m_iDeaths", entity.get_local_player())
			local legit_deaths_width = renderer.measure_text("-d", "DEATHS:-")
			renderer.text(ui.get(player_stats_x) + legit_kills_width + 15, ui.get(player_stats_y) + 50, 255, 255, 255, 255, "-d", 0, "DEATHS:")
			renderer.text(ui.get(player_stats_x) + legit_deaths_width + legit_kills_width + 15, ui.get(player_stats_y) + 50, menuR, menuG, menuB, menuA, "-d", 0, m_iDeaths)
			-- kdr
			--if m_iDeaths ~= 0 then kdr = (m_iKills/m_iDeaths) elseif m_iKills ~= 0 then kdr = m_iKills end
			--renderer.rectangle(ui.get(player_stats_x) + 1, ui.get(player_stats_y) + 63, 80, 5, 0, 0, 0, 100)
			--if m_iDeaths >= 0 then 
			--	kdr = m_iKills
			--	print(kdr)
			--	renderer.rectangle(ui.get(player_stats_x) + 2, ui.get(player_stats_y) + 64, math.clamp(kdr, 0, m_iKills) / m_iKills * 78, 3, menuR, menuG, menuB, menuA)
			--end
		end
			
		if client.key_state(0x01) and (mouse_position_y > ui.get(player_stats_y) and mouse_position_y < ui.get(player_stats_y) + player_stats_h) and (mouse_position_x > ui.get(player_stats_x) and mouse_position_x < ui.get(player_stats_x) + player_stats_w) then
			ui.set(player_stats_x, math.clamp(mouse_position_x - 50, 0, width - 102))
			ui.set(player_stats_y, math.clamp(mouse_position_y - 40, 0, height - 81))
		end
	end
end

-- spectators /done
local function spectators()
	if ui.get(player_spectators_checkbox) then
		-- variables
		local spectators = {}
		local spectators_title_width = renderer.measure_text("-d", "SPECTATORS")

		for i = 1, 64 do
			if entity.get_prop(i, "m_hObserverTarget") ~= nil and entity.get_prop(i, "m_hObserverTarget") == entity.get_local_player() and not entity.is_alive(i) then 
				spectators[#spectators+1] = i 
			end
		end

		if #spectators > 0 or ui.is_menu_open()then
			-- draw spectators
			-- rendering
			-- redering background
			renderer.blur(ui.get(spec_list_x), ui.get(spec_list_y), 101, 11 + #spectators * 10, 0, 0, 0, 255)
			renderer.rectangle(ui.get(spec_list_x), ui.get(spec_list_y), 101, 10 + #spectators * 10, 0, 0, 0, 100)
			-- title
			renderer.text(ui.get(spec_list_x) + spectators_title_width / 1.85, ui.get(spec_list_y), 255, 255, 255, 255, "-d", 0, "SPECTATORS")
			-- right side
			renderer.gradient(ui.get(spec_list_x) + 101, ui.get(spec_list_y), 1, 11 + #spectators * 10, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)
			-- bottom
			renderer.rectangle(ui.get(spec_list_x) , ui.get(spec_list_y) + 10 + #spectators * 10, 101, 1, menuR, menuG, menuB, menuA)
			-- left side
			renderer.gradient(ui.get(spec_list_x) - 1, ui.get(spec_list_y), 1, 11 + #spectators * 10, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)
		end

		for i = 1, #spectators do 
			local spectator = spectators[i]
			
			if string.len(entity.get_player_name(spectator)) > 18 then
				-- if spectator name has more than 18 letters add "..." at the end
				renderer.text(ui.get(spec_list_x) , (ui.get(spec_list_y)) + (i*10), 255, 255, 255, 255, "-d", 0, string.sub(string.upper(entity.get_player_name(spectator)), 1, 18) .. "...")
			else
				renderer.text(ui.get(spec_list_x) , (ui.get(spec_list_y)) + (i*10), 255, 255, 255, 255, "-d", 0, string.upper(entity.get_player_name(spectator)))
			end
		end
		
		if client.key_state(0x01) and (mouse_position_y > ui.get(spec_list_y) and mouse_position_y < ui.get(spec_list_y) + spec_list_h) and (mouse_position_x > ui.get(spec_list_x) and mouse_position_x < ui.get(spec_list_x) + spec_list_w) then
			ui.set(spec_list_x, math.clamp(mouse_position_x - 50, 0, width - 102))
			ui.set(spec_list_y, math.clamp(mouse_position_y - 40, 0, height - 81))
		end	
	end
end

-- bomb time
local function bomb()
	if ui.get(bomb_checkbox) then
		-- get bomb
		local planted_c4 = entity.get_all("CPlantedC4")[1]
		-- check if bomb is planted or defused
		if planted_c4 == nil or entity.get_prop(planted_c4, "m_bBombDefused") == 1 then return end
		-- get bomb explode timer
		local c4_blow = entity.get_prop(planted_c4, "m_flC4Blow") - globals.curtime()
		
		-- if blow timer reaches 0 then it stops rendering
		if c4_blow >= 0 then
			--variables
			-- site where bomb is planted
			local c4_site = entity.get_prop(planted_c4, "m_nBombSite")
			-- get the site out of "c4_site"
			if c4_site == 0 then bomb_info.site = "A" elseif c4_site == 1 then bomb_info.site = "B" else bomb_info.site = "unknown" end
			-- bomb "max" time to blow
			local c4_max_time = client.get_cvar("mp_c4timer")

			-- rendering
			-- redering background
			renderer.blur(width / 2 - 100, height / 1.2, 200, 5, 0, 0, 0, 255)
			renderer.rectangle(width / 2 - 100, height / 1.2, 200, 5, 0, 0, 0, 100)

			-- bombsite in which bomb is planted
			local site_width = renderer.measure_text("-d", "BOMBSITE:  " .. bomb_info.site)
			renderer.text(width / 2 - (site_width / 2), height / 1.22, 255, 255, 255, 255, "-d", 0, "BOMBSITE:  ")
			renderer.text(width / 2 + (site_width / 2.5), height / 1.22, menuR, menuG, menuB, menuA, "-d", 0, bomb_info.site)

			-- bomb blow timer
			local bomb_time_width = renderer.measure_text("-d", string.format("%.f",c4_blow) .. "S")
			-- if time to blow below 5s then rect is red
			if tonumber(c4_blow) <= 5 then 
				renderer.rectangle(width / 2 - 99, height / 1.2 + 1, math.clamp((string.format("%.f",c4_blow) / c4_max_time) * 198, 0, 198), 3, 211, 50, 50, 255)
			-- if time to blow below 10s then rect is yellow
			elseif tonumber(c4_blow) <= 10 then 
				renderer.rectangle(width / 2 - 99, height / 1.2 + 1, math.clamp((string.format("%.f",c4_blow) / c4_max_time) * 198, 0, 198), 3, 255, 150, 50, 255)
			-- if time to blow above 10s then rect is "menu color"
			else
				renderer.rectangle(width / 2 - 99, height / 1.2 + 1, math.clamp((string.format("%.f",c4_blow) / c4_max_time) * 198, 0, 198), 3, menuR, menuG, menuB, menuA)
			end

			renderer.text(width / 2 - 99 + math.clamp((string.format("%.f",c4_blow) / c4_max_time) * 198, 0, 198), height / 1.192, 255, 255, 255, 255, "-d", 0, string.format("%.2f",c4_blow) .. "S")
		end
	end
end

-- others /done
local function others()
end

-- console filter /done
ui.set_callback(set_console, function()
	if ui.get(set_console) then
		cvar.developer:set_int(0)
		cvar.con_filter_enable:set_int(1) 
		cvar.con_filter_text:set_string("IrWL5106TZZKNFPz4P4Gl3pSN?J370f5hi373ZjPg%VOVh6lN")
		client.exec("cl_showerror 0")
	else
		cvar.con_filter_enable:set_int(0)
		cvar.con_filter_text:set_string("")
	end
end)

-- better doubletap
ui.set_callback(better_doubletap, function()
	if entity.is_alive(entity.get_local_player()) then
		if ui.get(better_doubletap) then
			cvar.cl_clock_correction:set_int(0)
			cvar.cl_clock_correction_adjustment_max_amount:set_int(450)
		end
	end
end)

-- shot logger /done
-- aim fire event
client.set_event_callback("aim_fire", function(e)
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
end)

-- aim hit event
client.set_event_callback("aim_hit", function(e)
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
		stats.limb_hit = stats.limb_hit + 1
	end

    if ui.get(hitlogs) then
        local name = entity.get_player_name(e.target)
        local hp_left = entity.get_prop(e.target, "m_iHealth")

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
end)

-- aim miss event
client.set_event_callback("aim_miss", function(e)
	
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

-- fast grenade /done
client.set_event_callback("grenade_thrown", function(e)
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
end)

-- setup command function
client.set_event_callback("setup_command", function(cmd)
	-- variables
	local localFlags = entity.get_prop(entity.get_local_player(), "m_fFlags")

	-- conditional exploits /done
	if ui.get(disable_exploits) then
		if (get_wpn_class(entity.get_local_player()) == "CKnife" and client.key_state(0x20)) then
			ui.set(references.doubleTap[1], false)
		elseif get_wpn_class(entity.get_local_player()) == "CWeaponTaser" then
			ui.set(references.doubleTap[1], false)
		elseif get_wpn_class(entity.get_local_player()) == "CC4" then
			ui.set(references.doubleTap[1], false)
		elseif get_wpn_class(entity.get_local_player()) == "CMolotovGrenade" or get_wpn_class(entity.get_local_player()) == "CSmokeGrenade" or get_wpn_class(entity.get_local_player()) == "CHEGrenade" or get_wpn_class(entity.get_local_player()) == "CFlashbang" or get_wpn_class(entity.get_local_player()) == "CDecoyGrenade" then
			ui.set(references.doubleTap[1], false)
		else
			ui.set(references.doubleTap[1], true)
		end
	end

	-- first person when holding nades
	if ui.get(first_person_nade) then
		if get_wpn_class(entity.get_local_player()) == "CMolotovGrenade" or get_wpn_class(entity.get_local_player()) == "CSmokeGrenade" or get_wpn_class(entity.get_local_player()) == "CHEGrenade" or get_wpn_class(entity.get_local_player()) == "CFlashbang" or get_wpn_class(entity.get_local_player()) == "CDecoyGrenade" then
			ui.set(references.thirdPerson[1], false)
		else
			ui.set(references.thirdPerson[1], true)
		end
	end

	-- remove shooting when the menu is open
	if ui.is_menu_open() then 
        cmd.in_attack = false
        cmd.in_attack2 = false
    end

	-- fakelag stuff
	if cmd.chokedcommands < OldChoke then --sent
		toDraw0 = toDraw1
		toDraw1 = toDraw2
		toDraw2 = toDraw3
		toDraw3 = toDraw4
		toDraw4 = OldChoke
	end
	OldChoke = cmd.chokedcommands
end)

client.set_event_callback("player_connect_full", function()
	-- variables
	hudElement = find_hud_element(hud, "CCSGO_HudChat") or error("CCSGO_HudChat not found")
    if (hudElement ~= nil) then
        hudChat = ffi.cast("CCSGO_HudChat*", hudElement)
    end

	-- stats
	stats.hits = 0
	stats.misses = 0
	stats.head_hit = 0
	stats.body_hit = 0
	stats.limb_hit = 0
	stats.total_shots = 0
	stats.miss_type = "NONE"
end)

-- buybot /done  
client.set_event_callback("player_spawn", function(e)
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
				client.exec("buy defuser")
			end
	  end
end)

-- auto disconnect /done
client.set_event_callback("cs_win_panel_match", function()
	if auto_dc then
		if entity.get_prop(entity.get_game_rules(), "m_bIsValveDS") == 1 then
			client.exec("disconnect")
		end
	end
end)

-- paint ui callback
client.set_event_callback("paint_ui", function()
	menu()
	watermark()
	if entity.is_alive(entity.get_local_player()) then
		bomb()
		--others()
		indicators()
		if not (hudChat ~= nil and hudChat.isChatOpen == true) then
			spectators()
			player_stats()
		end
	end
end)

-- callbacks / commands
-- sets commands
--optimazation commands
cvar.r_3dsky:set_int(0)
cvar.r_3dskyinreflection:set_int(0)
-- clears console
client.exec("clear")
-- plays a sound
client.exec("play player/playerping")
-- callbacks
-- "finished loading" callback
client.color_log(menuR, menuG, menuB, "[hyuga] \0")
client.color_log(211, 211, 211, "Finished loading " .. FileName)
-- "visit discord" callback
client.color_log(menuR, menuG, menuB, "[hyuga] \0")
client.color_log(50, 211, 50, "Discord: https://discord.io/reub")

client.set_event_callback("shutdown", function()
	-- reset commands
	cvar.con_filter_enable:set_int(0)
    cvar.con_filter_text:set_string("")
	-- clears console
	client.exec("clear")
	-- "finished loading" callback
	client.color_log(menuR, menuG, menuB, "[hyuga] \0")
	client.color_log(211, 50, 50, "Unloaded")
end)
