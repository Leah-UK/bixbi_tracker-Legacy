ESX = nil 
Citizen.CreateThread(function() 
    while ESX == nil do 
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end) 
        Citizen.Wait(1) 
    end
end) 

AddEventHandler('onResourceStart', function(resourceName)
	if (resourceName == GetCurrentResourceName() and Config.Debug) then
		while (ESX == nil) do
            Citizen.Wait(100)
        end
        
        Citizen.Wait(10000)
        ESX.PlayerLoaded = true
		StartScript()
	end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler("esx:playerLoaded", function(xPlayer)
	ESX.PlayerData = xPlayer

	Citizen.Wait(2000)
	StartScript()
end)

function StartScript()
	while (ESX == nil) do
		Citizen.Wait(1)
	end
	ESX.PlayerLoaded = true

	TriggerEvent('bixbi_tracker:CheckTags')
	if (Config.Jobs[ESX.PlayerData.job.name] ~= nil and Config.Jobs[ESX.PlayerData.job.name].autojoin and exports['bixbi_core']:itemCount('tracker') > 0) then
		JoinGroup(ESX.PlayerData.playerId)
	end

	TrackerBlipLoop()
	TrackerTagBlipLoop()
	TrackerItemCheckLoop()
end

RegisterNetEvent('esx:onPlayerLogout')
AddEventHandler('esx:onPlayerLogout', function()
	ESX.PlayerLoaded = false
	ESX.PlayerData = {}
	trackedGroup = nil
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	ESX.PlayerData.job = job
	TriggerEvent('bixbi_tracker:CheckTags')
end)

function RemoveBlipById(id)
	local possible_blip = GetBlipFromEntity(GetPlayerPed(GetPlayerFromServerId(id)))
	if possible_blip ~= 0 then
		RemoveBlip(possible_blip)
	end
end

RegisterNetEvent('bixbi_tracker:notify')
AddEventHandler("bixbi_tracker:notify", function(type, msg)
	exports['bixbi_core']:Notify(type, msg)
end)

--[[--------------------------------------------------
Tracker Code
]]----------------------------------------------------
local trackedGroup = nil
RegisterNetEvent('bixbi_tracker:UpdateAll')
AddEventHandler("bixbi_tracker:UpdateAll", function(group)
	trackedGroup = group
end)

RegisterNetEvent('bixbi_tracker:TagReason')
AddEventHandler("bixbi_tracker:TagReason", function(reason)
	tagReason = reason
end)

RegisterNetEvent('bixbi_tracker:RemoveByID')
AddEventHandler("bixbi_tracker:RemoveByID", function(playerId)
	RemoveBlipById(playerId)
end)

RegisterNetEvent('bixbi_tracker:RemoveClient')
AddEventHandler("bixbi_tracker:RemoveClient", function()
	trackedGroup = nil
end)

hasTracker = false
function TrackerBlipLoop()
	Citizen.CreateThread(function()
		while ESX.PlayerLoaded do
			if trackedGroup ~= nil and hasTracker then
				for i, user in ipairs(trackedGroup.users) do
					local player = GetPlayerFromServerId(user.playerId)
					local ped = GetPlayerPed(player)
	
					if GetPlayerPed(-1) ~= ped and GetBlipFromEntity(ped) == 0 then
						local blip = AddBlipForEntity(ped)
						SetBlipSprite(blip, 1)
						SetBlipColour(blip, user.colour)
						SetBlipAsShortRange(blip, true)
						SetBlipDisplay(blip, 4)
						BeginTextCommandSetBlipName("STRING")
						AddTextComponentString(user.name)
						EndTextCommandSetBlipName(blip)
					end
				end
			end
			Citizen.Wait(Config.BlipCheckTime * 1000)
		end
	end)
end

function TrackerItemCheckLoop()
	Citizen.CreateThread(function()
		while ESX.PlayerLoaded do
			if trackedGroup ~= nil then
				local itemCount = exports['bixbi_core']:itemCount('tracker')
				while (itemCount == nil) do
					Citizen.Wait(100)
				end
				if itemCount == 0 then
					TriggerServerEvent('bixbi_tracker:RemoveAtId', trackedGroup.name, GetPlayerServerId(PlayerId()))
					trackedGroup = nil
					hasTracker = false
				else
					hasTracker = true
				end
			end
			Citizen.Wait(Config.ItemCheckTime * 1000)
		end
	end)
end

function IsInRestrictedList(groupName)
	for k,v in pairs(Config.RestrictedGroups) do
		if v == groupName then
			return true
		end
	end
	return false
end

function JoinGroup(source)
	local source = GetPlayerServerId(PlayerId())

	if Config.Jobs[ESX.PlayerData.job.name] ~= nil then
		local group = ESX.PlayerData.job.name
		if Config.Jobs[ESX.PlayerData.job.name].parent ~= nil then
			group = Config.Jobs[ESX.PlayerData.job.name].parent
		end

		if Config.Jobs[ESX.PlayerData.job.name].colour == -1 or Config.Jobs[ESX.PlayerData.job.name].selfcolour == true then
			TrackerMenu(group, Config.Jobs[ESX.PlayerData.job.name].colour)
		else
			TriggerServerEvent('bixbi_tracker:Add', source, group, Config.Jobs[ESX.PlayerData.job.name].colour)
			ESX.UI.Menu.CloseAll()
		end
	else
		ESX.UI.Menu.Open(
		'dialog', GetCurrentResourceName(), 'GroupName',
		{
		title = "Name of Group"
		},
		function(data4, menu4)
			local group = data4.value

			if Config.Jobs[group] == nil and IsInRestrictedList(group) == false then
				TrackerMenu(group, -1)
			else
				exports['bixbi_core']:Notify('error', Config.TrackerName .. _U('no_access'))
				ESX.UI.Menu.CloseAll()
			end
			
		end, function(data4, menu4)
			menu4.close()
		end)
	end
end

--[[--------------------------------------------------
Tag Code
]]----------------------------------------------------
local taggedPlayers = nil
local tagReason = nil
RegisterNetEvent('bixbi_tracker:CheckTags')
AddEventHandler("bixbi_tracker:CheckTags", function()
	if Config.EnableTrackerTag then
		local playerId = GetPlayerServerId(PlayerId())

		if Config.TagJobs[ESX.PlayerData.job.name] ~= nil then
			TriggerServerEvent('bixbi_tracker:TagForceUpdate', playerId)
		end
	end
end)

RegisterNetEvent('bixbi_tracker:TagUpdateAll')
AddEventHandler("bixbi_tracker:TagUpdateAll", function(tags)
	taggedPlayers = tags
end)

RegisterNetEvent('bixbi_tracker:RemoveTagItem')
AddEventHandler("bixbi_tracker:RemoveTagItem", function()
	exports['bixbi_core']:Loading(10000, 'Removing Tag')
	exports['bixbi_core']:playAnim(PlayerPedId(), 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', -1, false)
	Citizen.Wait(10000)

	ClearPedTasks(PlayerPedId())
	
	local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
	if closestPlayer ~= -1 and closestDistance <= 3.0 then
		TriggerServerEvent('bixbi_tracker:TagRemoveAtId', GetPlayerServerId(closestPlayer))
	end
end)


function TrackerTagBlipLoop()
	if Config.EnableTrackerTag then
		Citizen.CreateThread(function()
			while ESX.PlayerLoaded do
				if taggedPlayers ~= nil and Config.TagJobs[ESX.PlayerData.job.name] ~= nil and hasTracker then
					for k in pairs(taggedPlayers) do
						local user = taggedPlayers[k]
						local player = GetPlayerFromServerId(user.id)
						local ped = GetPlayerPed(player)
	
						if GetPlayerPed(-1) ~= ped and GetBlipFromEntity(ped) == 0 then
							local blip = AddBlipForEntity(ped)
							SetBlipSprite(blip, 188)
							SetBlipColour(blip, 3)
							SetBlipAsShortRange(blip, true)
							SetBlipDisplay(blip, 4)
							BeginTextCommandSetBlipName("STRING")
							AddTextComponentString(user.name .. ' - ' .. user.reason)
							EndTextCommandSetBlipName(blip)
						end
					end
				end
				Wait(Config.TagBlipCheckTime * 1000)
			end
		end)
	end
end

--[[--------------------------------------------------
ESX Menu Code
]]----------------------------------------------------

RegisterNetEvent('bixbi_tracker:OpenMenu')
AddEventHandler("bixbi_tracker:OpenMenu", function(source)
	ESX.UI.Menu.CloseAll()
	if source == nil then source = GetPlayerServerId(PlayerId()) end

	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'MainMenu', {
		title    = Config.TrackerName .. 'Main Menu',
		align    = 'right',
		elements = {
			{label = 'Join', value = 'join'},
			{label = 'Disband', value = 'disband'},
			{label = 'Leave', value = 'leave'}

	}}, function(data, menu)
		if data.current.value == 'join' then
			JoinGroup(source)
		elseif data.current.value == 'disband' then
			if trackedGroup ~= nil then
				if trackedGroup.owner == source and trackedGroup.name ~= "emergency" then
					TriggerServerEvent('bixbi_tracker:Remove', trackedGroup.name)
					trackedGroup = nil
				else
					exports['bixbi_core']:Notify('error', Config.TrackerName .. _U('group_owner', trackedGroup.owner))
				end
			end
			ESX.UI.Menu.CloseAll()
		elseif data.current.value == 'leave' then
			if trackedGroup ~= nil then
				TriggerServerEvent('bixbi_tracker:RemoveAtId', trackedGroup.name, source)
				trackedGroup = nil
			else
				exports['bixbi_core']:Notify('error', Config.TrackerName .. _U('consuccess'))
			end
			
			ESX.UI.Menu.CloseAll()
		end	
	end, function(data, menu)
		menu.close()
	end)
end)

function TrackerMenu(group, colourInput)
	ESX.UI.Menu.CloseAll()
	local source = GetPlayerServerId(PlayerId())

	local elements = {
		{label = _U('red'), value = 'red'},
		{label = _U('green'), value = 'green'},
		{label = _U('blue'), value = 'blue'},
		{label = _U('purple'), value = 'purple'},
		{label = _U('pink'), value = 'pink'},
		{label = _U('yellow'), value = 'yellow'},
		{label = _U('white'), value = 'white'}
	}

	if colourInput ~= -1 then
		table.insert(elements, {label = 'Default', value = 'default'})
	end


	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'TrackerColour', {
		title    = 'Tracker Colour',
		align    = 'right',
		elements = elements

	}, function(data2, menu2)
		local colourChosen = data2.current.value
		local colour = 0
		if colourChosen == 'red' then
			colour = 1
		elseif colourChosen == 'green' then
			colour = 2
		elseif colourChosen == 'blue' then
			colour = 3
		elseif colourChosen == 'purple' then
			colour = 27
		elseif colourChosen == 'pink' then
			colour = 34
		elseif colourChosen == 'yellow' then
			colour = 46
		elseif colourChosen == 'default' then
			colour = colourInput
		else
			colour = 0
		end

		TriggerServerEvent('bixbi_tracker:Add', source, group, colour)
		ESX.UI.Menu.CloseAll()

	end, function(data2, menu2)
		menu2.close()
	end)
end


RegisterNetEvent('bixbi_tracker:OpenTagMenu')
AddEventHandler("bixbi_tracker:OpenTagMenu", function(source)
	ESX.UI.Menu.CloseAll()
	if source == nil then source = GetPlayerServerId(PlayerId()) end

	if Config.TagJobs[ESX.PlayerData.job.name] == nil then
		exports['bixbi_core']:Notify('error', Config.TrackerName .. 'you cannot access this.')
		return
	end

	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'MainMenu', {
		title    = Config.TrackerName .. 'Main Menu',
		align    = 'right',
		elements = {
			{label = 'Add Tag', value = 'add'},
			{label = 'Remove Tag', value = 'remove'}

	}}, function(data, menu)
		if data.current.value == 'add' then
			AddNewTag()
		elseif data.current.value == 'remove' then
			-- TriggerEvent('bixbi_tracker:RemoveTagItem')
		end
	end, function(data, menu)
		menu.close()
	end)
end)

function AddNewTag()
	ESX.UI.Menu.CloseAll()

	local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
	if closestPlayer ~= -1 and closestDistance <= 3.0 then
		local keyboard = exports["nh-keyboard"]:KeyboardInput({
			header = "Add Tag", 
			rows = {
				{
					id = 0, 
					txt = "Reason"
				},
				{
					id = 1, 
					txt = "Length (minutes)"
				}
			}
		})
		if keyboard ~= nil then
			if keyboard[1].input == nil or keyboard[2].input == nil then return end
			if tonumber(keyboard[2].input == nil) then return end
	
			exports['bixbi_core']:Loading(10000, 'Applying Tag')
			exports['bixbi_core']:playAnim(PlayerPedId(), 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', -1, false)
			Citizen.Wait(10000)
			ClearPedTasks(PlayerPedId())
	
			TriggerServerEvent('bixbi_tracker:TaggerAdd', GetPlayerServerId(PlayerId()), true, GetPlayerServerId(closestPlayer), keyboard[1].input, tonumber(keyboard[2].input) * 1000)
		end
	end
end

-- function RemoveTag()
-- 	ESX.UI.Menu.CloseAll()

-- 	ESX.UI.Menu.Open(
-- 	'dialog', GetCurrentResourceName(), 'Remove-Tag-ID',
-- 	{
-- 	title = "User ID"
-- 	},
-- 	function(data2, menu2)
-- 		local userid = data2.value

-- 		TriggerEvent('bixbi_tracker:RemoveTagItem', userid)
-- 		ESX.UI.Menu.CloseAll()
-- 	end, function(data2, menu2)
-- 		menu2.close()
-- 	end)
-- end