ESX = nil
TriggerEvent("esx:getSharedObject", function(obj) ESX = obj end)

--[[--------------------------------------------------
Tracker Code
]]----------------------------------------------------
local groupBlips = {}
local trackedPlayers = {}

ESX.RegisterUsableItem('tracker', function(source)
    TriggerClientEvent('bixbi_tracker:OpenMenu', source)
end)

function IsInGroup(id)
	if trackedPlayers[id] == nil then
		return false
	else
		TriggerClientEvent('bixbi_core:Notify', id, 'error', Config.TrackerName .. _U('tracking_group', trackedPlayers[id]))
		return true
	end
end

ESX.RegisterServerCallback('bixbi_tracker:NewGroupConnection', function(source, cb, group)
	local result = false
	if groupBlips[group] ~= nil then result = true end
	cb(result)
end)

RegisterServerEvent('bixbi_tracker:TagForceUpdate')
AddEventHandler('bixbi_tracker:TagForceUpdate', function(id)
	TriggerClientEvent('bixbi_tracker:TagUpdateAll', id, taggedPlayers)
end)

RegisterServerEvent('bixbi_tracker:Add')
AddEventHandler('bixbi_tracker:Add', function(id, group, colour)
	if IsInGroup(id) == false then
		if groupBlips[group] == nil or groupBlips[group].users == { } then
			local xPlayer = ESX.GetPlayerFromId(id)
			groupBlips[group] = {}
			groupBlips[group].owner = id
			groupBlips[group].name = group
			groupBlips[group].users = { }

			table.insert(groupBlips[group].users, { playerId = id, name = xPlayer.name, colour = colour })
			
			trackedPlayers[id] = group
			TriggerClientEvent('bixbi_core:Notify', id, '', Config.TrackerName .. _U('created_group', group))
			TriggerClientEvent('bixbi_tracker:UpdateAll', id, groupBlips[group])
		else
			local currentIds = groupBlips[group].users
			local alreadySaved = false
	
			for i,groupId in ipairs(groupBlips[group].users) do
				if groupId.playerId == id then
					alreadySaved = true
				end 
			end
	
			if alreadySaved == false then
				local xPlayer = ESX.GetPlayerFromId(id)
				table.insert(groupBlips[group].users, { playerId = id, name = xPlayer.name, colour = colour })
				trackedPlayers[id] = group

				for i,player in ipairs(groupBlips[group].users) do
					TriggerClientEvent('bixbi_core:Notify', player.playerId, '', Config.TrackerName .. _U('group_joined', xPlayer.name))
					TriggerClientEvent('bixbi_tracker:UpdateAll', player.playerId, groupBlips[group])
				end
			end
		end
	end
end)

RegisterServerEvent('bixbi_tracker:RemoveAtId')
AddEventHandler('bixbi_tracker:RemoveAtId', function(group, id)
	local newGroup = {}
	trackedPlayers[id] = nil

	TriggerClientEvent('bixbi_core:Notify', id, '', Config.TrackerName .. _U('group_left', group))

	for i, user in ipairs(groupBlips[group].users) do
		if user.playerId ~= id then
			table.insert(newGroup, user)
		end
	end
	
	groupBlips[group].users = newGroup

	for i, user in ipairs(groupBlips[group].users) do
		TriggerClientEvent("bixbi_tracker:RemoveByID", user.playerId, id)
		TriggerClientEvent("bixbi_tracker:RemoveByID", id, user.playerId)
		TriggerClientEvent('bixbi_tracker:UpdateAll', user.playerId, groupBlips[group])
	end
end)

RegisterServerEvent('bixbi_tracker:Remove')
AddEventHandler('bixbi_tracker:Remove', function(group)
	for i, user in ipairs(groupBlips[group].users) do
		TriggerClientEvent('bixbi_core:Notify', user.playerId, '', Config.TrackerName .. _U('disbanded'))
		TriggerEvent("bixbi_tracker:RemoveAtId", group, user.playerId)
		TriggerClientEvent("bixbi_tracker:RemoveClient", user.playerId)
		trackedPlayers[user.playerId] = nil
	end
	groupBlips[group] = nil
end)

--[[--------------------------------------------------
Tag Code
]]----------------------------------------------------
if (Config.EnableTrackerTag) then
	ESX.RegisterUsableItem('trackertag', function(source)
		TriggerClientEvent('bixbi_tracker:OpenTagMenu', source)
	end)

	-- ESX.RegisterUsableItem('trackertagremover', function(source)
	-- 	local xPlayer = ESX.GetPlayerFromId(source)
	-- 	xPlayer.removeInventoryItem('trackertagremover', 1)
	-- 	TriggerClientEvent('bixbi_tracker:RemoveTagItem', source)
	-- end)

	local taggedPlayers = {}
	AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
		Citizen.Wait(1000)
		MySQL.Async.fetchAll('SELECT bixbi_tag FROM users WHERE identifier = @identifier', {
			['@identifier'] = xPlayer.identifier
		}, function(result)
			for _,v in pairs(result) do
				local info = json.decode(v.bixbi_tag)
				if info.time > 0 then
					TriggerEvent('bixbi_tracker:TaggerAdd', false, playerId, info.reason, info.time)
				end
			end
		end)
	end)

	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(Config.TagCheckTime * 1000)

			for playerId, player in pairs(taggedPlayers) do
				if (tonumber(player.time) > 0) then
					local UpdateInfo = {time = math.ceil(player.time - (Config.TagCheckTime * 1000)), reason = player.reason}
					taggedPlayers[playerId].time = math.ceil(player.time - (Config.TagCheckTime * 1000))
					
					MySQL.Async.execute('UPDATE users SET bixbi_tag = @bixbi_tag WHERE identifier = @identifier', {		
						['@identifier'] = player.xpid,
						['@bixbi_tag'] = json.encode(UpdateInfo)
					})
				else
					TriggerEvent('bixbi_tracker:TagRemoveAtId', playerId)
				end
			end
		end
	end)

	RegisterServerEvent('bixbi_tracker:TagRemoveAtId')
	AddEventHandler('bixbi_tracker:TagRemoveAtId', function(id)
		print(id)
		local xPlayer = ESX.GetPlayerFromId(id)
		taggedPlayers[id] = nil
		TriggerClientEvent('bixbi_core:Notify', id, '', Config.TrackerName .. _('tag_notracked'))
		
		local xPlayers = ESX.GetPlayers()
		for i=1, #xPlayers, 1 do
			local xPlayerA = ESX.GetPlayerFromId(xPlayers[i])
			if Config.TagJobs[xPlayerA.job.name] ~= nil then
				TriggerClientEvent("bixbi_tracker:RemoveByID", xPlayerA.playerId, id)
				TriggerClientEvent('bixbi_core:Notify', xPlayerA.playerId, 'error', Config.TrackerName .. _U('tag_removed', xPlayer.name))
				TriggerClientEvent('bixbi_tracker:TagUpdateAll', xPlayers[i], taggedPlayers)
			end
		end

		MySQL.Async.execute('UPDATE users SET bixbi_tag = @bixbi_tag WHERE identifier = @identifier', {		
			['@identifier'] = xPlayer.identifier,
			['@bixbi_tag'] = '{"time":0,"reason":""}'
		})
	end)

	RegisterServerEvent('bixbi_tracker:TaggerAdd')
	AddEventHandler('bixbi_tracker:TaggerAdd', function(isNew, id, reason, time)
		if taggedPlayers[id] == nil and id ~= nil then
			local xPlayer = ESX.GetPlayerFromId(id)
			if xPlayer ~= nil then
				taggedPlayers[id] = {}
				taggedPlayers[id].name = xPlayer.name
				taggedPlayers[id].reason = reason
				taggedPlayers[id].id = id
				taggedPlayers[id].time = time
				taggedPlayers[id].xpid = xPlayer.identifier
				
				xPlayer.triggerEvent('bixbi_core:Notify', '', Config.TrackerName .. _U('tag_tracked'))
				xPlayer.triggerEvent('bixbi_tracker:TagReason', reason)
				
				local xPlayers = ESX.GetPlayers()
				for i=1, #xPlayers, 1 do
					local xPlayerA = ESX.GetPlayerFromId(xPlayers[i])
					if Config.TagJobs[xPlayerA.job.name] ~= nil then
						xPlayerA.triggerEvent('bixbi_core:Notify', 'error', Config.TrackerName .. _U('tag_added', xPlayer.name))
						xPlayerA.triggerEvent('bixbi_tracker:TagUpdateAll', taggedPlayers)
					end
				end
			end

			if (isNew) then
				local UpdateInfo = {time = tonumber(time), reason = reason}				
				MySQL.Async.execute('UPDATE users SET bixbi_tag = @bixbi_tag WHERE identifier = @identifier', {		
					['@identifier'] = xPlayer.identifier,
					['@bixbi_tag'] = json.encode(UpdateInfo)
				})
			end
		end
	end)
end

--[[--------------------------------------------------
Vehicle Tag Code
]]----------------------------------------------------
-- if (Config.EnableVehicleTracking) then
-- 	ESX.RegisterUsableItem('trackerveh', function(source)
-- 		TriggerClientEvent('bixbi_tracker:OpenVehTagMenu', source)
-- 	end)

-- 	local taggedVehicles = {}
-- 	RegisterServerEvent('bixbi_tracker:VehAdd')
-- 	AddEventHandler('bixbi_tracker:VehAdd', function(plate, group)
-- 		if taggedVehicles[plate] == nil and plate ~= nil then
-- 			taggedVehicles[plate] = {}
-- 			taggedVehicles[plate].group = group
			
-- 			for i,player in ipairs(groupBlips[group].users) do
-- 				TriggerClientEvent('bixbi_core:Notify', player.playerId, 'info', Config.TrackerName .. _U('veh_tracked', plate))
-- 				TriggerClientEvent('bixbi_tracker:VehUpdateAll', player.playerId, taggedVehicles)
-- 			end
-- 		end
-- 	end)

-- 	RegisterServerEvent('bixbi_tracker:VehRemovePlate')
-- 	AddEventHandler('bixbi_tracker:VehRemovePlate', function(plate)
-- 		local vehTag = taggedVehicles[plate]
-- 		taggedVehicles[plate] = nil

-- 		local xPlayers = ESX.GetPlayers()
-- 		for i=1, #xPlayers, 1 do
-- 			local xPlayerA = ESX.GetPlayerFromId(xPlayers[i])
-- 			if Config.TagJobs[xPlayerA.job.name] ~= nil then
-- 				TriggerClientEvent('bixbi_core:Notify', xPlayerA.playerId, 'error', Config.TrackerName .. _U('veh_trackdel', plate))
-- 				TriggerClientEvent('bixbi_tracker:TagUpdateAll', xPlayers[i], taggedVehicles)
-- 			end
-- 		end
-- 	end)
-- end


AddEventHandler("playerDropped", function()
	if IsInGroup(source) then 
		TriggerEvent('bixbi_tracker:RemoveByID', trackedPlayers[source], source)
	end
end)

AddEventHandler('onResourceStart', function(resourceName)
	if (GetResourceState('bixbi_core') ~= 'started' ) then
        print('Bixbi_Tracker - ERROR: Bixbi_Core hasn\'t been found! This could cause errors!')
    end
end)