-- mods/lagcheck/init.lua
-- =================
-- See README.md for licensing and other information.

--ABM

lagcheck_abm = {}
abm_count = 0
abm_last = {}
local old_register_abm = minetest.register_abm
function minetest.register_abm(spec)
	abm_count = abm_count + 1
	if abm_last.mod ~= minetest.get_current_modname() then
		abm_last.mod = minetest.get_current_modname()
		abm_last.count = 1
	else
		abm_last.count = abm_last.count + 1
	end
	lagcheck_abm[abm_count] = {mod = (minetest.get_current_modname() or "Unknown") .." (".. abm_last.count ..")", data = {}}
	spec.id = abm_count
	spec.action2 = spec.action
	spec.action = function(pos, node, active_object_count, active_object_count_wider)
		local time1 = minetest.get_us_time()
		spec.action2(pos, node, active_object_count, active_object_count_wider)
		table.insert(lagcheck_abm[spec.id].data, minetest.get_us_time() - time1 > 0 and minetest.get_us_time() - time1 or 0)
	end
	return old_register_abm(spec)
end

--Globalstep

lagcheck_globalstep = {}
globalstep_count = 0
globalstep_last = {}
local old_register_globalstep = minetest.register_globalstep
function minetest.register_globalstep(spec)
	globalstep_count = globalstep_count + 1
	if globalstep_last.mod ~= minetest.get_current_modname() then
		globalstep_last.mod = minetest.get_current_modname()
		globalstep_last.count = 1
	else
		globalstep_last.count = globalstep_last.count + 1
	end
	lagcheck_globalstep[globalstep_count] = {mod = (minetest.get_current_modname() or "Unknown") .." (".. globalstep_last.count ..")", data = {}}
	local spec_old = spec
	spec = function(dtime)
		local time1 = minetest.get_us_time()
		spec_old(dtime)
		table.insert(lagcheck_globalstep[globalstep_count].data, minetest.get_us_time() - time1 > 0 and minetest.get_us_time() - time1 or 0)
	end
	return old_register_globalstep(spec)
end

--Print out

local function sort_tablefunc(a)
	local aall = 0
	local amin = a[1] or 0
	local amax = a[1] or 0
	for key, value in ipairs(a.data) do
		aall = aall + value
		if value > amax then
			amax = value
		end
		if value < amin then
			amin = value
		end
	end
	return {min = amin, max = amax, all = #a.data == 0 and -1 or aall / #a.data}
end

local function sort_table(a, b)
	a = sort_tablefunc(a).all
	b = sort_tablefunc(b).all
	if a > b then
		return true
	end
	return false
end

local formatted = string.format("%%-%ds | %%%ds | %%%ds | %%%ds", 25, 9, 9, 9)

minetest.register_chatcommand("lagcheck", {
	description = "Writes lagcheck",
	privs = {privs = true},
	func = function(name, param)
		local file = io.open(minetest.get_worldpath() .."/LagCheck.txt", "w")
		
		--ABM
		local str = "ABM:\n\n"
		str = str .. string.format(formatted, "Modname", "Average", "Min", "Max") .."\n"
		table.sort(lagcheck_abm, function(a, b) return sort_table(a, b) end)
		for key, value in ipairs(lagcheck_abm) do
			local data = sort_tablefunc(value)
			str = str .. string.format(formatted, value.mod, tostring(math.floor(data.all)), tostring(math.floor(data.min)), tostring(math.floor(data.max))) .."\n"
		end
		
		--Globalstep
		str = str .."\n\nGlobalstep:\n\n"
		str = str .. string.format(formatted, "Modname", "Average", "Min", "Max") .."\n"
		table.sort(lagcheck_globalstep, function(a, b) return sort_table(a, b) end)
		for key, value in ipairs(lagcheck_globalstep) do
			local data = sort_tablefunc(value)
			str = str .. string.format(formatted, value.mod, tostring(math.floor(data.all)), tostring(math.floor(data.min)), tostring(math.floor(data.max))) .."\n"
		end
		
		file:write(str)
		file:close()
		minetest.chat_send_player(name, "Lagcheck: File saved to world folder")
end})

