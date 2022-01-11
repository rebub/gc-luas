-- require
local ffi = require "ffi"
local easing = require "gamesense/easing"
local images = require "gamesense/images"
local anti_aim = require "gamesense/antiaim_funcs"

-- ffi 
local def = ffi.cdef([[ 
    typedef struct MaterialAdapterInfo_t {
            char m_pDriverName[512];
            unsigned int m_VendorID;
            unsigned int m_DeviceID;
            unsigned int m_SubSysID;
            unsigned int m_Revision;
            int m_nDXSupportLevel;
            int m_nMinDXSupportLevel;
            int m_nMaxDXSupportLevel;
            unsigned int m_nDriverVersionHigh;
            unsigned int m_nDriverVersionLow;
    };

	typedef int(__thiscall* get_current_adapter_fn)(void*);
    typedef void(__thiscall* get_adapter_info_fn)(void*, int adapter, struct MaterialAdapterInfo_t& info);

    typedef struct {
        float x,y,z;
    } vec3_t_aojnsfdghuinfasiugnhiusfnghsfghsfgh;

    struct tesla_info_t_ioajdngfhijafgidjnhuangfdhargh {
        vec3_t_aojnsfdghuinfasiugnhiusfnghsfghsfgh  m_pos;
        vec3_t_aojnsfdghuinfasiugnhiusfnghsfghsfgh  m_ang;
        int m_entindex;
        const char *m_spritename;
        float m_flbeamwidth;
        int m_nbeams;
        vec3_t_aojnsfdghuinfasiugnhiusfnghsfghsfgh m_color;
        float m_fltimevis;
        float m_flradius;
    };

    typedef void(__thiscall* FX_TeslaFn_iosjfdnghjusfgiuhisfgihsfgjshfgshfj)(struct tesla_info_t_ioajdngfhijafgidjnhuangfdhargh&);
    ]])

	
-- hwid variables & others
local material_system = client.create_interface('materialsystem.dll', 'VMaterialSystem080')
local material_interface = ffi.cast('void***', material_system)[0]

local get_current_adapter = ffi.cast('get_current_adapter_fn', material_interface[25])
local get_adapter_info = ffi.cast('get_adapter_info_fn', material_interface[26])

local current_adapter = get_current_adapter(material_interface)

local adapter_struct = ffi.new('struct MaterialAdapterInfo_t')
get_adapter_info(material_interface, current_adapter, adapter_struct)

local driverName = tostring(ffi.string(adapter_struct['m_pDriverName']))
local vendorId = tostring(adapter_struct['m_VendorID'])
local deviceId = tostring(adapter_struct['m_DeviceID'])
local sysID = tostring(adapter_struct['m_SubSysID'])

hwid = (vendorId * deviceId + sysID)

-- global variables
local reub = 76561198384716464
local width, height = client.screen_size()
local key_states = {
    [0] = 'Always on',
    [1] = 'On hotkey',
    [2] = 'Toggle',
    [3] = 'Off hotkey'
}

-- panorama 
local js = panorama.open()
local name, steamid = js.MyPersonaAPI.GetName() , js.MyPersonaAPI.GetXuid()
local menuR, menuG, menuB, menuA = ui.get(ui.reference("Misc", "Settings", "Menu color"))

local match = client.find_signature("client_panorama.dll", "\x55\x8B\xEC\x81\xEC\xCC\xCC\xCC\xCC\x56\x57\x8B\xF9\x8B\x47\x18")
	local fs_tesla = ffi.cast("FX_TeslaFn_iosjfdnghjusfgiuhisfgihsfgjshfgshfj", match)

-- watermark variables
local watermark_prefix = "hyuga "

-- clantag variables
local clantags = {"hyūga"}
local clantag_prev

-- fast grenade variables
local switch_to_flash_at = nil
local next_command_at = nil

-- indicator variables /dt
local doubletap_charge = 0

-- spectator list variables
	

-- ragebot stats variables
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

-- menu elements (lua, a tab)
-- hud elements
ui.new_label("LUA", "A", "Hud Elements")
watermark_checkbox = ui.new_checkbox("LUA", "A", "Watermark")
indicators_checkbox = ui.new_checkbox("LUA", "A", "Indicators")
player_spectators_checkbox = ui.new_checkbox("LUA", "A", "Spectators")
player_stats_checkbox = ui.new_checkbox("LUA", "A", "Player Stats")

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
hitlogs = ui.new_checkbox("LUA", "A", "Hitlog")
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
	aimbot = { ui.reference("LEGIT", "Aimbot", "Enabled") } ,
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

-- time to ticks function
local function time_to_ticks(t)
	return math.floor(0.5 + (t / globals.tickinterval()))
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

-- paint
-- menu stuff
local function menu()
	if ui.is_menu_open() then

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

		-- crosshair /done
		client.exec("cl_crosshaircolor_r ", menuR, "; cl_crosshaircolor_g ", menuG, "; cl_crosshaircolor_b ", menuB)

		local qpm, qpcolor = ui.reference("RAGE", "Other", "Quick peek assist mode")
		ui.set(qpcolor, menuR, menuG, menuB, menuA)

		local oofc, oofcolor = ui.reference("VISUALS", "Player ESP", "Out of fov arrow")
		ui.set(oofcolor, menuR, menuG, menuB, menuA)

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
			while ui.get(player_stats_checkbox) or ui.get(player_spectators_checkbox) do
				if pos_checkbox_check == true then
					pos_checkbox_check = false
					ui.set(position_sliders, true)
				end
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

local function player_hurt(e)
	local me = entity.get_local_player()
	local attacker = client.userid_to_entindex(e.attacker)
	if attacker == me then 
		local hurt = client.userid_to_entindex(e.userid)
		local x = client.random_float(-20000, 20000)
		local y = client.random_float(-x, x)
		local z = client.random_float(-y, y)

		local tesla_info = ffi.new("struct tesla_info_t_ioajdngfhijafgidjnhuangfdhargh")
		tesla_info.m_flbeamwidth = 20
		tesla_info.m_flradius = 200
		tesla_info.m_entindex = attacker
		tesla_info.m_color = {menuR/255, menuG/255, menuB/255}
		tesla_info.m_pos = { entity.hitbox_position(hurt, 6) }
		tesla_info.m_ang = {x,y,z}
		tesla_info.m_fltimevis = 2
		tesla_info.m_nbeams = 2
		tesla_info.m_spritename = "sprites/physbeam.vmt"
		fs_tesla(tesla_info)
	end
end

client.set_event_callback("player_hurt", player_hurt)

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
	--print(entity.get_prop(entity.get_local_player(), "m_flDuckAmount"))
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
		if ui.get(references.enabled_rage) then
			stats.min_dmg = ui.get(references.minDamage) 

			if stats.min_dmg > 100 then
				stats.min_dmg = "HP+".. (stats.min_dmg - 100)
			end

			-- rendering
			-- redering background
			renderer.blur(ui.get(player_stats_x), ui.get(player_stats_y), 101, 80, 0, 0, 0, 255)
			renderer.rectangle(ui.get(player_stats_x), ui.get(player_stats_y), 101, 80, 0, 0, 0, 100)
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
					renderer.text(15, height - 265, 255, 255, 255, 255, "-d", 0, string.upper("limb hits: " .. stats.limb_hit))
					-- hit or miss state
					if (stats.miss_or_hit ~= nil) then
						renderer.text(15, height - 245, 255, 255, 255, 255, "-d", 0, string.upper("shot type:  -"))
					end
					renderer.text(15, height - 245, 255, 255, 255, 255, "-d", 0, string.upper("shot type:" .. stats.miss_or_hit)) 
				end
			end
		else
			-- variables
			local playerresource = entity.get_all("CCSPlayerResource")[1]
			-- rendering
			-- redering background
			renderer.blur(ui.get(player_stats_x), ui.get(player_stats_y), 101, 70, 0, 0, 0, 255)
			renderer.rectangle(ui.get(player_stats_x), ui.get(player_stats_y), 101, 70, 0, 0, 0, 100)
			-- right side
			renderer.gradient((ui.get(player_stats_x) + 101), ui.get(player_stats_y), 1, 71, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)
			-- bottom
			renderer.rectangle(ui.get(player_stats_x), ui.get(player_stats_y) + 70, 101, 1, menuR, menuG, menuB, menuA)
			-- left side
			renderer.gradient(ui.get(player_stats_x), ui.get(player_stats_y), 1, 71, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)

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
			local kdr_width = renderer.measure_text("-d", "KDR:-")
			if m_iDeaths ~= 0 then kdr = (m_iKills/m_iDeaths) elseif m_iKills ~= 0 then kdr = m_iKills end
			renderer.text(ui.get(player_stats_x), ui.get(player_stats_y) + 60, 255, 255, 255, 255, "-d", 0, "KDR:")
			if not kdr ~= nil then
				renderer.text(ui.get(player_stats_x) + kdr_width, ui.get(player_stats_y) + 60, menuR, menuG, menuB, menuA, "-d", 0, string.format("%.2f",kdr))
			else
				renderer.text(ui.get(player_stats_x) + kdr_width, ui.get(player_stats_y) + 60, menuR, menuG, menuB, menuA, "-d", 0, "0")
			end
		end
	end
end

-- spectators
local function spectators()
	if ui.get(player_spectators_checkbox) then
		-- variables
		local spectators = {}

		for i = 1, 64 do
			if entity.get_prop(i, "m_hObserverTarget") ~= nil and entity.get_prop(i, "m_hObserverTarget") == entity.get_local_player() and not entity.is_alive(i) then 
				spectators[#spectators+1] = i 
			end
		end

		if not spectator == nil then
			-- rendering
			-- redering background
			renderer.blur(ui.get(spec_list_x) , ui.get(spec_list_y), 101, 80, 0, 0, 0, 255)
			renderer.rectangle(ui.get(spec_list_x) , ui.get(spec_list_y), 101, 80, 0, 0, 0, 100)
			-- right side
			renderer.gradient(ui.get(spec_list_x)  + 101, ui.get(spec_list_y), 1, 81, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)
			-- bottom
			renderer.rectangle(ui.get(spec_list_x) , ui.get(spec_list_y) + 80, 101, 1, menuR, menuG, menuB, menuA)
			-- left side
			renderer.gradient(ui.get(spec_list_x)  - 1, ui.get(spec_list_y), 1, 81, menuR, menuG, menuB, 0, menuR, menuG, menuB, menuA, false)

			-- title
			local spectators_title_width = renderer.measure_text("-d", "SPECTATORS")
			renderer.text(ui.get(spec_list_x) + spectators_title_width / 1.95, ui.get(spec_list_y), 255, 255, 255, 255, "-d", 0, "SPECTATORS")

			for i = 1, #spectators do 
				local spectator = spectators[i]
				
				-- draw spectators
				if string.len(entity.get_player_name(spectator)) > 18 then
					-- if spectator name has more than 18 letters add "..." at the end
					renderer.text(ui.get(spec_list_x) , (ui.get(spec_list_y) + 10) + (i*10), 255, 255, 255, 255, "-d", 0, string.sub(string.upper(entity.get_player_name(spectator)), 1, 18) .. "...")
				else
					renderer.text(ui.get(spec_list_x) , (ui.get(spec_list_y) + 10) + (i*10), 255, 255, 255, 255, "-d", 0, string.upper(entity.get_player_name(spectator)))
				end
			end
		else end
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
	ui.set_callback(set_console, function()
		if ui.get(set_console) then
			cvar.developer:set_int(0)
			cvar.con_filter_enable:set_int(1) 
			cvar.con_filter_text:set_string("IrWL5106TZZKNFPz4P4Gl3pSN?J370f5hi373ZjPg%VOVh6lN")
			client.exec("cl_showerror 0")
		else
			cvar.con_filter_enable:set_int(0)
			cvar.con_filter_text:set_string("")
			client.exec("cl_showerror 1")
		end
	end)
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
		  	client.exec("buy defuser")
	  	end
	end
end
  
client.set_event_callback("player_spawn", buy)

-- paint ui callback
client.set_event_callback("paint_ui", function()
	menu()
	watermark()
	if entity.is_alive(entity.get_local_player()) then
		indicators()
		spectators()
		player_stats()
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
client.color_log(211, 211, 211, "Finished loading")
-- "visit discord" callback
client.color_log(menuR, menuG, menuB, "[hyuga] \0")
client.color_log(50, 211, 50, "Discord: https://discord.io/reub")

client.set_event_callback("shutdown", function()
    cvar.con_filter_enable:set_int(0)
    cvar.con_filter_text:set_string("")
end)
