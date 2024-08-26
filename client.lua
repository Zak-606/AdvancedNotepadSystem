local isNotepadVisible = false
local pages = {} -- Initialize pages as an empty table
local notepadSettings = {
    position = json.decode(GetResourceKvpString("notepadPosition") or '{"x":"50%","y":"50%"}'),
    size = json.decode(GetResourceKvpString("notepadSize") or '{"width":400,"height":600,"scale":1}')
}
local isWritingSoundPlaying = false
local writingSoundTimer = nil

-- Add these at the top of the file
local droppedNotes = {}
local noteObject = `prop_notepad_01` -- or any other appropriate prop

-- Add these animation dictionaries at the top of your file
local pickupDict = "anim@mp_snowball"
local pickupAnim = "pickup_snowball"
local destroyDict = "anim@mp_player_intcelebrationmale@knuckle_crunch"
local destroyAnim = "knuckle_crunch"

local function savePages()
    if not pages then pages = {} end -- Ensure pages is not nil
    local encodedPages = json.encode(pages)
    SetResourceKvp("notepadPages", encodedPages)
    print("Saving pages: " .. encodedPages) -- Debug print
end

local function loadPages()
    local savedPages = GetResourceKvpString("notepadPages")
    if savedPages then
        pages = json.decode(savedPages)
        if not pages then pages = {} end -- Ensure pages is not nil if decode fails
        print("Loaded pages: " .. savedPages) -- Debug print
    else
        pages = {} -- Initialize as empty table if no saved data
        print("No saved pages found, initializing empty table") -- Debug print
    end
end

local function toggleNotepad(toggle)
    isNotepadVisible = toggle
    SetNuiFocus(toggle, toggle)
    SendNUIMessage({
        type = 'toggleNotepad',
        status = toggle,
        pages = pages or {}, -- Ensure we always send a table, even if empty
        position = notepadSettings.position,
        size = notepadSettings.size
    })
end

-- Add this function to drop a note
function dropNote(pageNumber)
    if pages[tostring(pageNumber)] then
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local heading = GetEntityHeading(playerPed)
        
        local noteData = {
            content = pages[tostring(pageNumber)],
            coords = coords,
            heading = heading
        }
        
        TriggerServerEvent('notepad:dropNote', noteData)
        
        -- Clear the page from the client's notepad
        pages[tostring(pageNumber)] = nil
        savePages()
        
        -- If the notepad is open, update it
        if isNotepadVisible then
            SendNUIMessage({
                type = 'updatePages',
                pages = pages
            })
        end
    else
        TriggerEvent('chat:addMessage', {args = {'^1Error', 'Page ' .. pageNumber .. ' is empty or does not exist.'}})
    end
end

-- Add this function to pick up a note
function pickUpNote(noteId)
    local playerPed = PlayerPedId()
    
    -- Request the animation dictionary
    RequestAnimDict(pickupDict)
    while not HasAnimDictLoaded(pickupDict) do
        Citizen.Wait(100)
    end
    
    -- Play the pickup animation
    TaskPlayAnim(playerPed, pickupDict, pickupAnim, 8.0, -8.0, -1, 0, 0, false, false, false)
    
    -- Wait for the animation to finish (adjust the time as needed)
    Citizen.Wait(2000)
    
    -- Clear the animation
    ClearPedTasks(playerPed)
    
    -- Trigger the server event to pick up the note
    TriggerServerEvent('notepad:pickUpNote', noteId)
end

-- Add this function to destroy a note
function destroyNote(noteId)
    local playerPed = PlayerPedId()
    
    -- Request the animation dictionary
    RequestAnimDict(destroyDict)
    while not HasAnimDictLoaded(destroyDict) do
        Citizen.Wait(100)
    end
    
    -- Play the destroy animation
    TaskPlayAnim(playerPed, destroyDict, destroyAnim, 8.0, -8.0, -1, 0, 0, false, false, false)
    
    -- Wait for the animation to finish (adjust the time as needed)
    Citizen.Wait(2000)
    
    -- Clear the animation
    ClearPedTasks(playerPed)
    
    -- Trigger the server event to destroy the note
    TriggerServerEvent('notepad:destroyNote', noteId)
end

RegisterCommand('notes', function() 
    loadPages() -- Load pages before opening
    toggleNotepad(true) 
end, false)

RegisterCommand('notepad', function() 
    loadPages() -- Load pages before toggling
    toggleNotepad(not isNotepadVisible) 
end, false)

RegisterCommand('clearnotes', function()
    pages = {}
    savePages()
    TriggerEvent('chat:addMessage', {color = {255, 255, 0}, args = {"SYSTEM", "All notes have been cleared."}})
    if isNotepadVisible then SendNUIMessage({type = 'clearNotes'}) end
end, false)

RegisterCommand('resetnotepad', function()
    local defaultSettings = {position = {x = "50%", y = "50%"}, size = {width = 400, height = 600, scale = 1}}
    SetResourceKvp("notepadPosition", json.encode(defaultSettings.position))
    SetResourceKvp("notepadSize", json.encode(defaultSettings.size))
    notepadSettings = defaultSettings
    TriggerEvent('chat:addMessage', {color = {255, 255, 0}, args = {"SYSTEM", "Notepad position and size have been reset to default."}})
    if isNotepadVisible then SendNUIMessage({type = 'resetNotepadSettings', position = notepadSettings.position, size = notepadSettings.size}) end
end, false)

-- Add this command to drop a note
RegisterCommand('dropnote', function(source, args)
    if #args ~= 1 then
        TriggerEvent('chat:addMessage', {args = {'^1Error', 'Usage: /dropnote [page number]'}})
        return
    end
    
    local pageNumber = tonumber(args[1])
    if pageNumber then
        dropNote(pageNumber)
    else
        TriggerEvent('chat:addMessage', {args = {'^1Error', 'Invalid page number.'}})
    end
end, false)

RegisterNUICallback('saveNotepadPosition', function(data, cb) notepadSettings.position = data; SetResourceKvp("notepadPosition", json.encode(data)); cb('ok') end)
RegisterNUICallback('saveNotepadSize', function(data, cb) notepadSettings.size = data; SetResourceKvp("notepadSize", json.encode(data)); cb('ok') end)
RegisterNUICallback('savePage', function(data, cb)
    if not pages then pages = {} end -- Ensure pages is not nil
    print("Saving page: " .. tostring(data.pageNumber) .. " - " .. tostring(data.content))
    pages[tostring(data.pageNumber)] = data.content
    savePages()
    cb('ok')
end)
RegisterNUICallback('deactivateNotepad', function(data, cb) 
    SetNuiFocus(false, false)
    savePages() -- Save pages when closing notepad
    cb('ok') 
end)

RegisterNUICallback('startWritingSound', function(data, cb)
    if not isWritingSoundPlaying then
        isWritingSoundPlaying = true
        TriggerServerEvent('notepad:startWritingSound')
    end
    if writingSoundTimer then RemoveTimer(writingSoundTimer) end
    writingSoundTimer = SetTimeout(1000, function()
        isWritingSoundPlaying = false
        TriggerServerEvent('notepad:stopWritingSound')
        writingSoundTimer = nil
    end)
    cb('ok')
end)

RegisterNUICallback('stopWritingSound', function(data, cb)
    if isWritingSoundPlaying then
        isWritingSoundPlaying = false
        TriggerServerEvent('notepad:stopWritingSound')
        if writingSoundTimer then
            RemoveTimer(writingSoundTimer)
            writingSoundTimer = nil
        end
    end
    cb('ok')
end)

Citizen.CreateThread(function()
    loadPages()
end)

RegisterNetEvent('notepad:playWritingSound')
AddEventHandler('notepad:playWritingSound', function()
    SendNUIMessage({type = 'playWritingSound'})
end)

-- Add this new event handler
RegisterNetEvent('notepad:checkNearbyPlayers')
AddEventHandler('notepad:checkNearbyPlayers', function(writerCoords)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    if #(playerCoords - writerCoords) <= 5.0 then
        local nearbyPlayers = GetNearbyPlayers(writerCoords, 5.0)
        TriggerServerEvent('notepad:notifyNearbyPlayers', nearbyPlayers)
    end
end)

-- Add this new function
function GetNearbyPlayers(coords, radius)
    local nearbyPlayers = {}
    local players = GetActivePlayers()
    
    for _, player in ipairs(players) do
        local targetPed = GetPlayerPed(player)
        local targetCoords = GetEntityCoords(targetPed)
        
        if #(coords - targetCoords) <= radius then
            table.insert(nearbyPlayers, GetPlayerServerId(player))
        end
    end
    
    return nearbyPlayers
end

-- Add this to handle note interactions
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        
        for noteId, noteData in pairs(droppedNotes) do
            local distance = #(coords - noteData.coords)
            
            if distance < 5.0 then
                Draw3DText(noteData.coords.x, noteData.coords.y, noteData.coords.z + 1.0, "Press ~g~E~w~ to pick up or ~r~G~w~ to destroy")
                
                if distance < 2.0 then
                    if IsControlJustReleased(0, 38) then -- E key
                        pickUpNote(noteId)
                    elseif IsControlJustReleased(0, 47) then -- G key
                        destroyNote(noteId)
                    end
                end
            end
        end
    end
end)

-- Add this function to draw 3D text
function Draw3DText(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
    local factor = (string.len(text)) / 370
    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
end

-- Add these event handlers
RegisterNetEvent('notepad:syncDroppedNotes')
AddEventHandler('notepad:syncDroppedNotes', function(notes)
    droppedNotes = notes
    for noteId, noteData in pairs(droppedNotes) do
        if not DoesEntityExist(noteData.object) then
            local object = CreateObject(noteObject, noteData.coords.x, noteData.coords.y, noteData.coords.z - 1, false, false, false)
            SetEntityHeading(object, noteData.heading)
            PlaceObjectOnGroundProperly(object)
            FreezeEntityPosition(object, true)
            noteData.object = object
        end
    end
end)

RegisterNetEvent('notepad:removeDroppedNote')
AddEventHandler('notepad:removeDroppedNote', function(noteId)
    if droppedNotes[noteId] and DoesEntityExist(droppedNotes[noteId].object) then
        DeleteObject(droppedNotes[noteId].object)
    end
    droppedNotes[noteId] = nil
end)

RegisterNetEvent('notepad:addPickedUpNote')
AddEventHandler('notepad:addPickedUpNote', function(content)
    local emptyPage = findEmptyPage()
    if emptyPage then
        pages[tostring(emptyPage)] = content
        savePages()
        TriggerEvent('chat:addMessage', {args = {'^2Success', 'Note added to page ' .. emptyPage}})
        if isNotepadVisible then
            SendNUIMessage({
                type = 'updatePages',
                pages = pages
            })
        end
    else
        TriggerEvent('chat:addMessage', {args = {'^1Error', 'No empty pages in your notepad.'}})
    end
end)

-- Add this function to find an empty page
function findEmptyPage()
    for i = 1, 100 do -- Assuming a maximum of 100 pages
        if not pages[tostring(i)] or pages[tostring(i)] == '' then
            return i
        end
    end
    return nil
end

-- Make sure all functions and event handlers are properly closed

-- No additional 'end' statement should be here