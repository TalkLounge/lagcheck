-- mods/euban/init.lua
-- =================
-- See README.txt for licensing and other information.

EUBan = {}
EUBan.Database = {}
EUBan.Whitelist = false
EUBan.SaveInterval = tonumber(minetest.setting_get("euban.saveinterval")) or 60*5 --Save interval of the database in seconds
EUBan.Enable_Limit = minetest.setting_getbool("euban.enable_limit") or false --Enable account limit
EUBan.Limit = tonumber(minetest.setting_get("euban.limit")) or 1 --How much accounts can be created by one ip subnet
EUBan.cutIPv4 = tonumber(minetest.setting_get("euban.cutIPv4")) or 1 --How much octaves will be cropped beginning at the end
EUBan.cutIPv6 = tonumber(minetest.setting_get("euban.cutIPv6")) or 4
EUBan.Path = minetest.get_worldpath() .."/EUBan.db"
local form_ban_reasons = {"Badname;Please choose a proper username", "Fake MT;You play an unofficial game! Official Game: Minetest\nPros of Minetest: No Ads & Free", "Insult;Please pay attention to your choice of words", "Vandalism;Vandalism isnt allowed here!", "Cheat;Hacks & Cheats arent allowed here! Please use an official Minetest releases"} --Predefined reasons for ban

local function read_file(Path)
	local file = io.open(Path, "r")
  if not file then
		return {}
	end
	local Database = minetest.deserialize(file:read("*a"))
	file:close()
	if not Database then
		return {}
	end
	return Database
end

EUBan.Database = read_file(EUBan.Path)

--Start of external source code

--By: Diego Martínez
--Mail: lkaezadl3@yahoo.com
--License: BSD 2 Clause License
--Taken: xban2 Mod for Minetest
--Link: https://github.com/minetest-mods/xban2/blob/master/serialize.lua

local function repr(x)
	if type(x) == "string" then
		return ("%q"):format(x)
	else
		return tostring(x)
	end
end

local function serialize(t, level)
	level = level or 0
	local lines = { }
	local indent = ("\t"):rep(level)
	for k, v in pairs(t) do
		local typ = type(v)
		if typ == "table" then
			table.insert(lines,
			  indent..("[%s] = {\n"):format(repr(k))
			  ..serialize(v, level + 1).."\n"
			  ..indent.."},")
		else
			table.insert(lines,
			  indent..("[%s] = %s,"):format(repr(k), repr(v)))
		end
	end
	return table.concat(lines, "\n")
end

--End of external source code

local function save_file(Path, Database)
	local file = io.open(Path, "w")
  file:write("return {\n"..serialize(Database, 1).."\n}")
  file:close()
end

local save_file_step_next = {}

local function save_file_step(Time, Path, Database)
	save_file_step_next[Path] = os.time() + Time
	minetest.after(Time, function()
			if Path == EUBan.Path then
				for name, main in pairs(Database) do
					if main.time and main.time <= os.time() then
						table.insert(EUBan.Database[name].reasons, {time = main.time})
						EUBan.Database[name].time = nil
						EUBan.Database[name].banned = nil
					end
				end
			end
			save_file(Path, Database)
			return save_file_step(Time, Path, Database)
	end)
end

save_file_step(EUBan.SaveInterval, EUBan.Path, EUBan.Database)

minetest.register_on_shutdown(function()
		save_file(EUBan.Path, EUBan.Database)
end)

local function is_ip(ipname)
	if ipname:find("%.") or ipname:find("%:") then
		return true
	end
end

local function shortip(ip)
	if ip:find("%.") then
		return (EUBan.cutIPv4 > 0 and ip:match("^".. string.rep("(.*)[.]", EUBan.cutIPv4)) or ip)
	elseif ip:find("%:") then
		local _, count = ip:gsub(":", "")
		return (EUBan.cutIPv6 - (7 - count) > 0 and ip:match("^".. string.rep("(.*)[:]", EUBan.cutIPv6 - (7 - count))) or ip)
	end
end

local function import_xban()
	local Database = read_file(minetest.get_worldpath() .."/xban.db") or {}
  Database["timestamp"] = nil
	for _, main in ipairs(Database) do
		for name, _ in pairs(main.names) do
			if not is_ip(name) then
				if not EUBan.Database[name] then
					EUBan.Database[name] = {ips = {}}
				end
				for ip, _ in pairs(main.names) do
					if is_ip(ip) then
						local exists = false
						for _, dbip in ipairs(EUBan.Database[name].ips) do
							if dbip == shortip(ip) then
								exists = true
							end
						end
						if not exists then
							table.insert(EUBan.Database[name].ips, shortip(ip))
						end
					end
				end
				for _, record in ipairs(main.record) do
					if not EUBan.Database[name].reasons then
						EUBan.Database[name].reasons = {}
					end
					local index = #EUBan.Database[name].reasons + 1
					for i, reason in ipairs(EUBan.Database[name].reasons) do
						if record.time == reason.time then
							index = false
							break
						elseif record.time < reason.time then
							index = i
						end
					end
					if index then
						table.insert(EUBan.Database[name].reasons, index, {user = record.source, status = true, time = record.time, message = record.reason})
					end
				end
				if main.banned then
					if main.expires then
						EUBan.Database[name].time = main.expires
					end
					EUBan.Database[name].banned = true
				end
			end
		end
	end
	save_file(EUBan.Path, EUBan.Database)
end

if #EUBan.Database == 0 then
  import_xban()
end

local function convert_time(time)
	if not time then
		return "Forever"
	end
  local minute = 60
  local hour = 60 * minute
  local day = 24 * hour
  local year = 365 * day
  if time > year then
    local years = math.floor((time / year) + 0.5)
    return years .." year".. (years > 1 and "s" or "") .." left"
  elseif time > day then
    local days = math.floor((time / day) + 0.5)
    return days .." day".. (days > 1 and "s" or "") .." left"
  elseif time > hour then
    local hours = math.floor((time / hour) + 0.5)
    return hours .." hour".. (hours > 1 and "s" or "") .." left"
  elseif time > minute then
    local minutes = math.floor((time / minute) + 0.5)
    return minutes .." minute".. (minutes > 1 and "s" or "") .." left"
  else
    return time .." second".. (time > 1 and "s" or "") .." left"
  end
end

function EUBan.status(Database)
	if not Database then
		return nil, nil, nil
	end
	local banned = nil
	local account = nil
	if Database.banned == false then
		banned = true
		account = true
	elseif Database.banned == true then
		banned = true
		account = false
	end
	local time = nil
	if type(Database.time) == "number" then
		if Database.time - os.time() <= 0 then
			banned = false
			account = false
			time = nil
		else
			time = Database.time - os.time()
		end
	end
	return banned, account, time --is banned, is only this account banned, time till unban
end

function EUBan.is_banned(playername, playerip)
	if minetest.get_player_privs(playername).privs then
		return
	end
	playerip = shortip(playerip)
	local banned, account, time = EUBan.status(EUBan.Database[playername])
	if banned then
		if account then
			return "Banned by name: ".. convert_time(time) .." Reason: ".. EUBan.Database[playername].reasons[#EUBan.Database[playername].reasons].message
		end
		return "Banned by ip: ".. convert_time(time) .." Reason: ".. EUBan.Database[playername].reasons[#EUBan.Database[playername].reasons].message
	end
  for name, main in pairs(EUBan.Database) do
    banned, account, time = EUBan.status(main)
		local exception = false
		for _, name in ipairs(main.exceptions or {}) do
			if name == playername then
				exception = true
			end
		end
		if banned and not account and not exception then
			for _, ip in ipairs(main.ips) do
        if ip == playerip then
					return "Banned by ip: ".. convert_time(time) .." Reason: ".. main.reasons[#main.reasons].message
				end
				for _, playerip in ipairs(EUBan.Database[playername] and EUBan.Database[playername].ips or {}) do
					if ip == playerip then
						return "Banned by ip: ".. convert_time(time) .." Reason: ".. main.reasons[#main.reasons].message
					end
				end
			end
		end
	end
end

local function record_login(playername, playerip)
  playerip = shortip(playerip)
  if EUBan.Database[playername] then
    for _, ip in ipairs(EUBan.Database[playername].ips) do
      if playerip == ip then
        return
      end
    end
    table.insert(EUBan.Database[playername].ips, playerip)
    return
  end
  EUBan.Database[playername] = {ips = {playerip}}
end

for name, main in pairs(EUBan.Database) do
	if main.whitelist then
		EUBan.Whitelist = true
		break
	end
end

function EUBan.is_whitelisted(playername)
	if EUBan.Whitelist and not minetest.get_player_privs(playername).privs and not (EUBan.Database[playername] and EUBan.Database[playername].whitelist) then
		return "You arent on the whitelist"
	end
end

function EUBan.player_exists(playername)
	return minetest.get_auth_handler().get_auth(playername) ~= nil
end

function EUBan.is_limited(playername, playerip)
	local accounts = EUBan.accounts(playername, playerip)
	local limit = EUBan.Limit
	for key, value in ipairs(accounts) do
		if EUBan.Database[value].limit then
			limit = limit + EUBan.Database[value].limit
		end
	end
	if EUBan.Enable_Limit and not minetest.player_exists(playername) and #accounts >= limit then
		return "Your account limit has already been reached. Cant create another new account"
	end
end

local Connections = {}

minetest.register_on_prejoinplayer(function(name, ip)
		if not name or not ip then
			return "Please try again"
		end
    local banned = EUBan.is_banned(name, ip)
    if banned then
      return banned
    end
		local whitelisted = EUBan.is_whitelisted(name)
		if whitelisted then
			return whitelisted
		end
		local limit = EUBan.is_limited(name, ip)
		if limit then
			return limit
		end
		Connections[name] = ip
end)

minetest.register_on_joinplayer(function(player)
		local name = player:get_player_name()
		record_login(name, Connections[name])
		Connections[name] = nil
end)

local form = {}

local function form_index(options, selected, cut)
  for index, op in ipairs(options) do
    if (not cut and selected == op) or (cut and op:sub(1, op:find(";") - 1) == selected) then
      return index
    end
  end
  return 1
end

local function sort_table(a, b)
	a = a:lower()
	b = b:lower()
	for i = 1, (a:len() > b:len() and a:len() or b:len()) do
		if a:len() < i then
			return true
		elseif b:len() < i then
			return false
		elseif string.byte(a, i) > string.byte(b, i) then
			return false
		elseif string.byte(a, i) < string.byte(b, i) then
			return true
		end
	end
end

local function connected_names()
	local names = {}
	for _, player in ipairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		if not minetest.get_player_privs(name).privs then
			table.insert(names, name)
		end
	end
	table.sort(names, function(a, b) return sort_table(a, b) end)
	return names
end

local function form_search(playername)
  local found = {}
  for account, main in pairs(EUBan.Database) do
    if (account:lower()):find(playername:lower()) and not minetest.get_player_privs(account).privs then
      table.insert(found, account)
    end
  end
	table.sort(found, function(a, b) return sort_table(a, b) end)
  return found
end

local form_ban_times = {"Forever", "Year(s)", "Day(s)", "Hour(s)", "Minute(s)", "Second(s)"}

local function form_ban(playername, fields)
  fields = fields or {}
	return "size[2.4,8]" ..
				 "label[0,0.26;Select player]" ..
				 "tabheader[0,0;euban_tab;Ban,Unban,Records,Whitelist,Limit;1;false;false]" ..
				 "dropdown[0,0.6;2.36,1;euban_ban_playerselect;".. table.concat(form[playername].euban_ban_playerselect, ",") ..";".. tostring(form[playername].euban_ban_playerselectindex) .."]" ..
				 "field[0.3,1.95;1.6,1;euban_ban_playersearchfield;;".. minetest.formspec_escape(fields.euban_ban_playersearchfield or "") .."]" ..
				 "field_close_on_enter[euban_ban_playersearchfield;false]" ..
				 "label[0.6,-0.1;Choose Player]" ..
				 "button[1.4,2.06;1,0;euban_ban_playersearch;Search]" ..
				 "label[0,1.36;Search player]" ..
				 "label[0.7,2.5;Choose Time]" ..
				 "field[0.3,3.2;1.2,1;euban_ban_timefield;;".. (fields.euban_ban_timefield or "") .."]" ..
				 "field_close_on_enter[euban_ban_timefield;false]" ..
				 "dropdown[1,2.95;1.3,1;euban_ban_timeselect;".. table.concat(form_ban_times, ",") ..";" .. tostring(form[playername].euban_ban_timeselectindex) .."]" ..
				 "label[0.8,3.8;Reason]" ..
				 "dropdown[0,4.45;2.36,1;euban_ban_reasonselect;".. ((table.concat(form_ban_reasons, ",") ..","):gsub(";(.-)[,]", ","):sub(1, -2)) ..";".. tostring(form[playername].euban_ban_reasonselectindex) .."]" ..
				 "textarea[0.3,5.5;2.4,2;euban_ban_reasonfield;;".. minetest.formspec_escape(fields.euban_ban_reasonfield or "Same reason as last time") .."]" ..
				 "label[0,4.1;Select predefined reason]" ..
				 "label[0,5.2;Write own reason]" ..
				 "button[0,7.2;1.3,1;euban_ban_banaccount;BAN:Account]" ..
				 "button[1.1,7.2;1.3,1;euban_ban_banall;BAN:Ip]"
end

minetest.register_chatcommand("euban", {
	description = "Show EUBan Formspec",
	privs = {ban = true},
	func = function(name)
		form[name] = {euban_ban_playerselect = connected_names(), euban_ban_playerselectindex = 1, euban_ban_timeselectindex = 1, euban_ban_reasonselectindex = 1}
		minetest.show_formspec(name, "euban:ban", form_ban(name))
end})

local function form_bany(playername)
	return "size[3.4,5.2]" ..
				 "label[1.5,0;Details]" ..
				 "label[0,0.5;Player:]" ..
				 "label[1,0.5;".. form[playername].euban_bany_player .."]" ..
				 "label[0,0.8;Time:]" ..
				 "label[1,0.8;".. form[playername].euban_bany_time .."]" ..
				 "label[0,1.1;Reason:]" ..
				 "textarea[1.3,1.2;2.4,2;euban_bany_reason;;".. minetest.formspec_escape(form[playername].euban_bany_reason) .."]" ..
				 "label[0,2.9;Accounts:\nDouble-click\nexceptions]" ..
				 "textlist[1,3;2.2,1.3;euban_bany_account;".. table.concat(form[playername].euban_bany_account, ",") .."]" ..
				 "button_exit[2.2,4.4;1.2,1;euban_bany_ban;BAN]" ..
				 "button[1,4.4;1.2,1;euban_bany_back;Back]"
end

function EUBan.accounts(playername, playerip)
	if not EUBan.Database[playername] and not playerip then
		return {}
	end
	playerip = playerip and shortip(playerip) or nil
	local names = {}
	for name, main in pairs(EUBan.Database) do
		local exception = false
		for _, name in ipairs(main.exceptions or {}) do
			if name == playername then
				exception = true
			end
		end
		if playerip and not exception then
			for _, ip in ipairs(main.exceptions or {}) do
				if ip == playerip then
					exception = true
				end
			end
		end
		if not exception and name ~= playername then
			for _, ip in ipairs(main.ips) do
				for _, playerip in ipairs(EUBan.Database[playername] and EUBan.Database[playername].ips or {playerip}) do
					if ip == playerip then
						local exists = false
						for _, exist in ipairs(names) do
							if name == exist then
								exists = true
							end
						end
						if not exists then
							table.insert(names, name)
						end
					end
				end
			end
		end
	end
	table.sort(names, function(a, b) return sort_table(a, b) end)
	return names or {}
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
  local playername = player:get_player_name()
	if formname ~= "euban:ban" or not minetest.get_player_privs(playername).ban or fields.quit then
    return
  end
	if fields.euban_ban_banaccount or fields.euban_ban_banall then
		if fields.euban_ban_playerselect == "" then
			minetest.chat_send_player(playername, "[Server]: Please select a player")
			return
		elseif fields.euban_ban_timeselect ~= "Forever" and not tonumber(fields.euban_ban_timefield) then
			minetest.chat_send_player(playername, "[Server]: Please enter a time")
			return
		elseif fields.euban_ban_reasonfield == "" then
			minetest.chat_send_player(playername, "[Server]: Please enter a reason")
			return
		end
		if fields.euban_ban_banaccount then
			form[playername].euban_bany_disaccount = nil
		else
			form[playername].euban_bany_disaccount = {}
		end
		form[playername].euban_bany_player = fields.euban_ban_playerselect
		form[playername].euban_bany_time = fields.euban_ban_timeselect == "Forever" and "Forever" or fields.euban_ban_timefield .." ".. fields.euban_ban_timeselect
		form[playername].euban_bany_reason = fields.euban_ban_reasonfield
		form[playername].euban_bany_account = fields.euban_ban_banaccount and {} or EUBan.accounts(form[playername].euban_bany_player)
		form[playername].euban_ban_playersearchfield = fields.euban_ban_playersearchfield
		form[playername].euban_ban_timefield = fields.euban_ban_timefield
		form[playername].euban_ban_reasonfield = fields.euban_ban_reasonfield
		minetest.show_formspec(playername, "euban:bany", form_bany(playername))
		return
	end
	if fields.euban_ban_playersearch then
		if fields.euban_ban_playersearchfield == "" then
			form[playername].euban_ban_playerselect = connected_names()
		else
			form[playername].euban_ban_playerselect = form_search(fields.euban_ban_playersearchfield)
			fields.euban_ban_playersearchfield = nil
		end
	end
	if fields.euban_ban_playerselect then
		form[playername].euban_ban_playerselectindex = form_index(form[playername].euban_ban_playerselect, fields.euban_ban_playerselect)
	end
	if fields.euban_ban_timeselect then
		form[playername].euban_ban_timeselectindex = form_index(form_ban_times, fields.euban_ban_timeselect)
	end
	if fields.euban_ban_reasonselect and (fields.euban_ban_reasonfield == "" or fields.euban_ban_reasonfield == "Same reason as last time") then
		form[playername].euban_ban_reasonselectindex = form_index(form_ban_reasons, fields.euban_ban_reasonselect, true)
		fields.euban_ban_reasonfield = form_ban_reasons[form[playername].euban_ban_reasonselectindex]:sub(fields.euban_ban_reasonselect:len() + 2)
	end
	fields.euban_ban_timefield = tonumber(fields.euban_ban_timefield) ~= nil and fields.euban_ban_timefield
	minetest.show_formspec(playername, "euban:ban", form_ban(playername, fields))
end)

function EUBan.ban(user, playername, account, time, reason, exceptions)
	if exceptions then
		for _, name in ipairs(exceptions) do
			if not EUBan.Database[name].exceptions then
				EUBan.Database[name].exceptions = {}
			end
			table.insert(EUBan.Database[name].exceptions, playername)
		end
	end
	if account then
		EUBan.Database[playername].banned = false
	else
		EUBan.Database[playername].banned = true
	end
	if type(time) == "number" then
		EUBan.Database[playername].time = time
	end
	if not EUBan.Database[playername].reasons then
		EUBan.Database[playername].reasons = {}
	end
	local reasons = {}
	if user and user ~= "" then
		reasons.user = user
	end
	if reason and reason ~= "" then
		reasons.message = reason
	end
	reasons.time = os.time()
	reasons.status = true
	table.insert(EUBan.Database[playername].reasons, reasons)
	for _, player in ipairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		local banned = EUBan.is_banned(name, minetest.get_player_ip(name))
		if banned then
			minetest.kick_player(name, banned)
		end
	end
	if time and time < save_file_step_next[EUBan.Path] then
		minetest.after(time - os.time(), function()
				EUBan.Database[playername].time = nil
				EUBan.Database[playername].banned = nil
		end)
	end
end

local function convert_time2(number, unit)
	local Unit = 1
	if unit:find("Year") then
		Unit = 60 * 60 * 24 * 365
	elseif unit:find("Day") then
		Unit = 60 * 60 * 24
	elseif unit:find("Hour") then
		Unit = 60 * 60
	elseif unit:find("Minute") then
		Unit = 60
	end
	return number * Unit
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
  local playername = player:get_player_name()
	if formname ~= "euban:bany" or not minetest.get_player_privs(playername).ban then
    return
  end
	if fields.euban_bany_ban then
		EUBan.ban(playername, form[playername].euban_bany_player, form[playername].euban_bany_disaccount and true, form[playername].euban_bany_time ~= "Forever" and convert_time2(tonumber(form[playername].euban_bany_time:match("%d+")), form[playername].euban_bany_time:match("%D+")) + os.time() or nil, form[playername].euban_ban_reasonfield, form[playername].euban_bany_disaccount)
		return
	end
	if fields.euban_bany_back then
		fields.euban_ban_playersearchfield = form[playername].euban_ban_playersearchfield
		fields.euban_ban_timefield = form[playername].euban_ban_timefield
		fields.euban_ban_reasonfield = form[playername].euban_ban_reasonfield
		minetest.show_formspec(playername, "euban:ban", form_ban(playername, fields))
		return
	end
	if fields.euban_bany_account and fields.euban_bany_account:sub(1, 3) == "DCL" and #form[playername].euban_bany_account ~= 0 then
		table.insert(form[playername].euban_bany_disaccount, form[playername].euban_bany_account[tonumber(fields.euban_bany_account:sub(5))])
		table.remove(form[playername].euban_bany_account, tonumber(fields.euban_bany_account:sub(5)))
	end
	minetest.show_formspec(playername, "euban:bany", form_bany(playername))
end)

function EUBan.banned()
	local names = {}
	for name, main in pairs(EUBan.Database) do
		if main.banned ~= nil then
			table.insert(names, name)
		end
	end
	table.sort(names, function(a, b) return sort_table(a, b) end)
	return names or {}
end

local function form_unban(playername, fields)
	fields = fields or {}
	form[playername].euban_unban_playerselect = form[playername].euban_unban_playerselect or EUBan.banned()
	return "size[2.4,5.6]" ..
				 "label[0,0.26;Select player]" ..
				 "tabheader[0,0;euban_tab;Ban,Unban,Records,Whitelist,Limit;2;false;false]" ..
				 "dropdown[0,0.6;2.36,1;euban_unban_playerselect;".. table.concat(form[playername].euban_unban_playerselect, ",") ..";".. (form[playername].euban_unban_playerselectindex and tostring(form[playername].euban_unban_playerselectindex) or "1") .."]" ..
				 "field[0.3,1.95;1.6,1;euban_unban_playersearchfield;;".. minetest.formspec_escape(fields.euban_unban_playersearchfield or "") .."]" ..
				 "field_close_on_enter[euban_unban_playersearchfield;false]" ..
				 "label[0.6,-0.1;Choose Player]" ..
				 "button[1.4,2.06;1,0;euban_unban_playersearch;Search]" ..
				 "label[0,1.36;Search player]" ..
				 "label[0.8,2.5;Reason]" ..
				 "textarea[0.3,3.1;2.4,2;euban_unban_reasonfield;;".. minetest.formspec_escape(fields.euban_unban_reasonfield or "") .."]" ..
				 "label[0,2.8;Write reason]" ..
				 "button[0.6,4.8;1.2,1;euban_unban_unban;UNBAN]"
end

function EUBan.unban(user, playername, reason)
	local reasons = {}
	if user and user ~= "" then
		reasons.user = user
	end
	if reason and reason ~= "" then
		reasons.message = reason
	end
	reasons.time = os.time()
	table.insert(EUBan.Database[playername].reasons, reasons)
	EUBan.Database[playername].time = nil
	EUBan.Database[playername].banned = nil
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
  local playername = player:get_player_name()
	if formname ~= "euban:unban" or not minetest.get_player_privs(playername).ban or fields.quit then
    return
  end
	if fields.euban_unban_unban then
		if fields.euban_unban_playerselect == "" then
			minetest.chat_send_player(playername, "[Server]: Please select a player")
			return
		end
		EUBan.unban(playername, fields.euban_unban_playerselect, fields.euban_unban_reasonfield)
		minetest.show_formspec(playername, "euban:unban", "")
		return
	end
	if fields.euban_unban_playersearch then
		if fields.euban_unban_playersearchfield == "" then
			form[playername].euban_unban_playerselect = EUBan.banned()
		else
			local search = {}
			for _, name in ipairs(form[playername].euban_unban_playerselect) do
				if (name:lower()):find(fields.euban_unban_playersearchfield:lower()) then
					table.insert(search, name)
				end
			end
			form[playername].euban_unban_playerselect = search
			fields.euban_unban_playersearchfield = nil
		end
	end
	if fields.euban_unban_playerselect then
		form[playername].euban_unban_playerselectindex = form_index(form[playername].euban_unban_playerselect, fields.euban_unban_playerselect)
	end
	minetest.show_formspec(playername, "euban:unban", form_unban(playername, fields))
end)

local function seperate(text, length)
	length = length or 51
	if text:len() <= length then
		return text
	end
	local seperated = ""
	while text ~= "" do
		local lastspace = length
		if text:len() > length then
			for i = length, 1, -1 do
				if text:sub(i, i) == " " then
					lastspace = i
					break
				end
			end
		end
		seperated = seperated .. (seperated:len() ~= 0 and ",".. minetest.formspec_escape(text:sub(1, lastspace)) or minetest.formspec_escape(text:sub(1, lastspace)))
		text = text:sub(lastspace + 1)
	end
	return seperated
end

local function form_records(playername, fields)
	fields = fields or {}
	form[playername].euban_records_list = form[playername].euban_records_list or form_search("")
	form[playername].euban_records_listindex = (form[playername].euban_records_listindex and form[playername].euban_records_listindex <= #form[playername].euban_records_list) and form[playername].euban_records_listindex or 1
	local Player = form[playername].euban_records_list[form[playername].euban_records_listindex]
	local Banned, Account, Time = EUBan.status(EUBan.Database[Player])
	local Ban = ""
	if Banned and Account then
		Ban = "Account, ".. (Time and convert_time(Time) or "Forever")
	elseif Banned then
		Ban = "IP, ".. (Time and convert_time(Time) or "Forever")
	end
	local Accounts = EUBan.accounts(Player)
	local Reasons = ""
	for index, main in ipairs(EUBan.Database[Player] and EUBan.Database[Player].reasons or {}) do
		Reasons = Reasons .. ",User: ".. (main.user or "Server") .." | Time: ".. os.date("%d.%m.%y %H:%M", main.time) .." | Type: ".. (main.status and "Ban" or "Unban") .." | Reason:".. (main.message and ",".. seperate(main.message) or "")
	end
	Reasons = Reasons:sub(2)
	return "size[8,4.8]" ..
				 "tabheader[0,0;euban_tab;Ban,Unban,Records,Whitelist,Limit;3;false;false]" ..
				 "textlist[0,0;2.3,3.9;euban_records_list;".. table.concat(form[playername].euban_records_list, ",") ..";".. tostring(form[playername].euban_records_listindex) .."]" ..
				 "field[0.3,4.2;1.6,1;euban_records_searchfield;;".. minetest.formspec_escape(fields.euban_records_searchfield or "") .."]" ..
				 "field_close_on_enter[euban_records_searchfield;false]" .. 
				 "button[1.4,3.88;1.1,1;euban_records_search;Search]" ..
				 "textlist[2.4,0.9;5.6,3.75;euban_records_list2;".. Reasons .."]" ..
				 "label[2.4,-0.1;Player:]" ..
				 "label[3.3,-0.1;".. (Player or "") .."]" ..
				 "label[2.4,0.2;Banned:]" ..
				 "label[3.3,0.2;".. Ban .."]" ..
				 "label[2.4,0.5;Accounts:]" ..
				 "label[3.3,0.5;".. table.concat(Accounts, ", ") .."]"
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
  local playername = player:get_player_name()
	if formname ~= "euban:records" or not minetest.get_player_privs(playername).ban or fields.quit then
    return
  end
	if fields.euban_records_search then
		if fields.euban_records_searchfield == "" then
			form[playername].euban_records_list = form_search("")
		else
			form[playername].euban_records_list = form_search(fields.euban_records_searchfield)
		end
	end
	if fields.euban_records_list then
		form[playername].euban_records_listindex = tonumber(fields.euban_records_list:sub(5))
	end
	minetest.show_formspec(playername, "euban:records", form_records(playername, fields))
end)

local function form_wl(playername, fields)
	fields = fields or {}
	form[playername].euban_wl_list = form[playername].euban_wl_list or {}
	form[playername].euban_wl_status = form[playername].euban_wl_status == nil and EUBan.Whitelist or form[playername].euban_wl_status
	return "size[2.4,4.6]" ..
				 "tabheader[0,0;euban_tab;Ban,Unban,Records,Whitelist,Limit;4;false;false]" ..
				 "textlist[0,0;2.3,2.6;euban_wl_list;".. table.concat(form[playername].euban_wl_list, ",") .."]" ..
				 "field[0.3,2.9;1.6,1;euban_wl_addfield;;".. minetest.formspec_escape(fields.euban_wl_addfield or "") .."]" ..
				 "field_close_on_enter[euban_wl_addfield;false]" ..
				 "button[1.41,2.58;1.09,1;euban_wl_add;Add]" ..
				 "checkbox[0,3.2;euban_wl_status;Enable Whitelist;".. (form[playername].euban_wl_status and "true" or "false") .."]" ..
				 "button[0.5,3.8;1.4,1;euban_wl_save;Update]"
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
  local playername = player:get_player_name()
	if formname ~= "euban:wl" or not minetest.get_player_privs(playername).privs or fields.quit then
    return
  end
	if fields.euban_wl_list and fields.euban_wl_list:sub(1, 3) == "DCL" and #form[playername].euban_wl_list ~= 0 then
		table.remove(form[playername].euban_wl_list, tonumber(fields.euban_wl_list:sub(5)))
	end
	if fields.euban_wl_add and fields.euban_wl_addfield ~= "" then
		if not EUBan.Database[fields.euban_wl_addfield] then
			minetest.chat_send_player(playername, "[Server]: Warning: ".. fields.euban_wl_addfield .." doesnt exist yet")
		end
		local exist = false
		for key, value in ipairs(form[playername].euban_wl_list) do
			if value == fields.euban_wl_addfield then
				exist = true
			end
		end
		if not exist then
			table.insert(form[playername].euban_wl_list, fields.euban_wl_addfield)
		end
		fields.euban_wl_addfield = nil
	end
	if fields.euban_wl_status == "true" then
		form[playername].euban_wl_status = true
	elseif fields.euban_wl_status == "false" then
		form[playername].euban_wl_status = false
	end
	if fields.euban_wl_save then
		if form[playername].euban_wl_status then
			EUBan.Whitelist = true
			for key, value in ipairs(form[playername].euban_wl_list) do
				if not EUBan.Database[value] then
					EUBan.Database[value] = {ips = {}, whitelist = true}
				end
			end
			for _, player in ipairs(minetest.get_connected_players()) do
				local name = player:get_player_name()
				local whitelisted = EUBan.is_whitelisted(name)
				if whitelisted then
					minetest.kick_player(name, whitelisted)
				end
			end
		else
			EUBan.Whitelist = false
			for name, main in pairs(EUBan.Database) do
				EUBan.Database[name].whitelist = nil
			end
		end
	end
	minetest.show_formspec(playername, "euban:wl", form_wl(playername, fields))
end)

local function form_limit(playername, fields)
	fields = fields or {}
	return "size[2.4,2.9]" ..
				 "tabheader[0,0;euban_tab;Ban,Unban,Records,Whitelist,Limit;5;false;false]" ..
				 "field[0.3,0.62;1.6,1;euban_limit_searchfield;;".. minetest.formspec_escape(fields.euban_limit_searchfield or "") .."]" ..
				 "field_close_on_enter[euban_limit_searchfield;false]" ..
				 "button[1.4,0.3;1.1,1;euban_limit_search;Select]" ..
				 "field[0.3,1.6;2.5,1;euban_limit_count;;".. minetest.formspec_escape(fields.euban_limit_count and fields.euban_limit_count or (form[playername].euban_limit_player and (EUBan.Database[form[playername].euban_limit_player].limit or 0) or 0)) .."]" ..
				 "field_close_on_enter[euban_limit_count;false]" ..
				 "label[0,0;Search player]" ..
				 "label[0,1;Account limit of ".. (form[playername].euban_limit_player or "") .."]" ..
				 "button[0.7,2.1;1.2,1;euban_limit_save;Save]"
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
  local playername = player:get_player_name()
	if formname ~= "euban:limit" or not minetest.get_player_privs(playername).privs or fields.quit then
    return
  end
	if fields.euban_limit_search and fields.euban_limit_searchfield ~= "" then
		if not EUBan.Database[fields.euban_limit_searchfield] then
			minetest.chat_send_player(playername, "[Server]: Player ".. fields.euban_limit_searchfield .." doesnt exist yet")
		else
			form[playername].euban_limit_player = fields.euban_limit_searchfield
			fields.euban_limit_searchfield = nil
			fields.euban_limit_count = nil
		end
	end
	if fields.euban_limit_save then
		if form[playername].euban_limit_player and tonumber(fields.euban_limit_count) ~= nil and tonumber(fields.euban_limit_count) >= 0 then
			EUBan.Database[form[playername].euban_limit_player].limit = tonumber(fields.euban_limit_count) > 0 and tonumber(fields.euban_limit_count) or nil
			minetest.show_formspec(playername, "euban:limit", "")
		elseif not form[playername].euban_limit_player then
			minetest.chat_send_player(playername, "[Server]: Please select a player first")
		else
			minetest.chat_send_player(playername, "[Server]: Please enter a number greater or equal than 0")
		end
	end
	minetest.show_formspec(playername, "euban:limit", form_limit(playername, fields))
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
  local playername = player:get_player_name()
	if (formname ~= "euban:ban" and formname ~= "euban:unban" and formname ~= "euban:records" and formname ~= "euban:wl" and formname ~= "euban:limit") or not fields.euban_tab or not minetest.get_player_privs(playername).ban or fields.quit then
    return
  end
	if fields.euban_tab == "1" then
		minetest.after(0.3, function()
				minetest.show_formspec(playername, "euban:ban", form_ban(playername))
		end)
	elseif fields.euban_tab == "2" then
		minetest.after(0.3, function()
				minetest.show_formspec(playername, "euban:unban", form_unban(playername))
		end)
	elseif fields.euban_tab == "3" then
		minetest.after(0.3, function()
				minetest.show_formspec(playername, "euban:records", form_records(playername))
		end)
	elseif fields.euban_tab == "4" and minetest.get_player_privs(playername).privs then
		minetest.after(0.3, function()
				minetest.show_formspec(playername, "euban:wl", form_wl(playername))
		end)
	elseif fields.euban_tab == "5" and minetest.get_player_privs(playername).privs then
		if not EUBan.Enable_Limit then
			minetest.chat_send_player(playername, "[Server]: Please activate this option in your minetest.conf: euban.enable_limit = true")
			return
		end
		minetest.after(0.3, function()
				minetest.show_formspec(playername, "euban:limit", form_limit(playername))
		end)
	end
end)

