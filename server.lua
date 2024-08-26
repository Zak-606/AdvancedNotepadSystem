local writingSoundPlayers = {}

RegisterServerEvent('notepad:startWritingSound')
AddEventHandler('notepad:startWritingSound', function()
    writingSoundPlayers[source] = true
end)

RegisterServerEvent('notepad:stopWritingSound')
AddEventHandler('notepad:stopWritingSound', function()
    writingSoundPlayers[source] = nil
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        for player in pairs(writingSoundPlayers) do
            local playerPed = GetPlayerPed(player)
            if DoesEntityExist(playerPed) then
                local playerCoords = GetEntityCoords(playerPed)
                TriggerClientEvent('notepad:checkNearbyPlayers', player, playerCoords)
            else
                writingSoundPlayers[player] = nil
            end
        end
    end
end)

RegisterServerEvent('notepad:notifyNearbyPlayers')
AddEventHandler('notepad:notifyNearbyPlayers', function(nearbyPlayerIds)
    for _, nearbyPlayer in ipairs(nearbyPlayerIds) do
        TriggerClientEvent('notepad:playWritingSound', nearbyPlayer)
    end
end)

-- New server script for note dropping/picking up/destroying
local droppedNotes = {}
local noteIdCounter = 0

RegisterServerEvent('notepad:dropNote')
AddEventHandler('notepad:dropNote', function(noteData)
    noteIdCounter = noteIdCounter + 1
    droppedNotes[noteIdCounter] = noteData
    TriggerClientEvent('notepad:syncDroppedNotes', -1, droppedNotes)
end)

RegisterServerEvent('notepad:pickUpNote')
AddEventHandler('notepad:pickUpNote', function(noteId)
    local noteData = droppedNotes[noteId]
    if noteData then
        droppedNotes[noteId] = nil
        TriggerClientEvent('notepad:removeDroppedNote', -1, noteId)
        TriggerClientEvent('notepad:addPickedUpNote', source, noteData.content)
    end
end)

RegisterServerEvent('notepad:destroyNote')
AddEventHandler('notepad:destroyNote', function(noteId)
    if droppedNotes[noteId] then
        droppedNotes[noteId] = nil
        TriggerClientEvent('notepad:removeDroppedNote', -1, noteId)
    end
end)

-- Sync dropped notes when a player joins
AddEventHandler('playerJoining', function()
    TriggerClientEvent('notepad:syncDroppedNotes', source, droppedNotes)
end)