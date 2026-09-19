--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-DOCTOR — Client: going down, lying there, coming back
     ═══════════════════════════════════════════════════════════════════════════
     A 500 ms watch notices the ped dying and tells the server once. While
     down the ped is kept in the wounded pose with controls off and the
     death card counting; the server's answer (revive, bed, respawn) ends it.
     Doctors act through lxr-interact options on people; offices are points.
     ═══════════════════════════════════════════════════════════════════════════
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local LXRCore = exports['lxr-core']:GetCoreObject()
local LXR = exports['lxr-core']:GetLXR()
local D = LXRDoctor
local N = Citizen.InvokeNative
local down, reported = false, false
local deadline = 0
local blips = {}

local function me() return LXRCore.PlayerData or {} end
local function isDoctor() return D.IsDoctor(me().job) end
local function toast(key, kind, vars) LXRCore.Notify(Lang:t(key, vars), kind or 'info') end
local function page(action, payload) SendNUIMessage({ action = action, payload = payload, brand = LXRCore.Brand, lang = Config.Lang, locale = Lang.bundle() }) end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ☠️ DOWN
-- ═══════════════════════════════════════════════════════════════════════════════
-- the wounded pose; when the dictionary does not load (or the game refuses the clip) the ped is
-- kept on the ground with a short ragdoll instead — a downed player never walks around
local poseOk = false
local function pose()
    local a = Config.Death.anim
    local ped = PlayerPedId()
    RequestAnimDict(a.dict)
    local t = GetGameTimer() + 1500
    while not HasAnimDictLoaded(a.dict) and GetGameTimer() < t do Wait(10) end
    if HasAnimDictLoaded(a.dict) then
        TaskPlayAnim(ped, a.dict, a.name, 8.0, -8.0, -1, 1, 0, false, false, false)
        Wait(150)
        poseOk = IsEntityPlayingAnim(ped, a.dict, a.name, 3)
    else
        poseOk = false
    end
    if not poseOk then SetPedToRagdoll(ped, 1200, 1200, 0, false, false, nil) end
end

local function standUp(health)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(ped), true, false)
    ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    ClearPedBloodDamage(ped)
    SetEntityHealth(ped, math.min(600, tonumber(health) or 200), 0)
    down = false reported = false
    page('hide')
end

RegisterNetEvent('lxr-doctor:client:down', function(seconds, at)
    if down then return end
    down = true
    deadline = GetGameTimer() + (tonumber(seconds) or Config.Death.bleedOutSeconds) * 1000
    local ped = PlayerPedId()
    -- keep the body: resurrect on the spot with a sliver of health and hold the wounded pose
    local pos = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(ped), true, false)
    ped = PlayerPedId()
    SetEntityHealth(ped, 120, 0)
    SetEntityInvincible(ped, true)
    pose()
    page('down', { seconds = tonumber(seconds) or Config.Death.bleedOutSeconds })
    CreateThread(function()
        local lastSent = -1
        while down do
            for _, c in ipairs(Config.Death.controlsWhileDown) do DisableControlAction(0, c, true) end
            if poseOk then
                if not IsEntityPlayingAnim(ped, Config.Death.anim.dict, Config.Death.anim.name, 3) then pose() end
            elseif not IsPedRagdoll(ped) then
                SetPedToRagdoll(ped, 1200, 1200, 0, false, false, nil)
            end
            local left = math.max(0, math.ceil((deadline - GetGameTimer()) / 1000))
            if left ~= lastSent then lastSent = left page('tick', { left = left }) end
            if left <= 0 and IsControlJustReleased(0, 0xCEFD9220) then   -- E: give up
                local ok, res, extra = LXR.RPC.Server('lxr-doctor:respawn')
                if ok then
                    DoScreenFadeOut(800) Wait(900)
                    SetEntityInvincible(ped, false)
                    NetworkResurrectLocalPlayer(res.spawn.x, res.spawn.y, res.spawn.z, res.spawn.w, true, false)
                    ped = PlayerPedId()
                    ClearPedTasksImmediately(ped) ClearPedBloodDamage(ped)
                    SetEntityHealth(ped, res.health, 0)
                    down = false reported = false
                    page('hide')
                    Wait(400) DoScreenFadeIn(800)
                    toast('info.woke', 'inform', { label = res.label, fee = ('%.2f'):format(res.fee or 0) })
                else toast('error.' .. tostring(res), 'error', { n = extra }) end
            end
            Wait(0)
        end
        SetEntityInvincible(PlayerPedId(), false)
    end)
end)

RegisterNetEvent('lxr-doctor:client:revive', function(health)
    -- a readable error if anything in the stand-up throws (a table error prints as "error object is not a string")
    local ok, err = xpcall(function()
        SetEntityInvincible(PlayerPedId(), false)
        standUp(health)
    end, function(e) return debug.traceback(type(e) == 'table' and json.encode(e) or tostring(e), 2) end)
    if not ok then print('^1[lxr-doctor]^7 revive failed: ' .. tostring(err)) end
end)
RegisterNetEvent('lxr-doctor:client:heal', function(add)
    local ped = PlayerPedId()
    SetEntityHealth(ped, math.min(600, GetEntityHealth(ped) + (tonumber(add) or 0)), 0)
end)

-- the death watch
CreateThread(function()
    while true do
        Wait(500)
        if LocalPlayer.state.isLoggedIn and not down and not reported then
            local ped = PlayerPedId()
            if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then
                reported = true
                local cause = 'unknown'
                if IsPedFatallyInjured(ped) then cause = 'injury' end
                TriggerServerEvent('lxr-doctor:server:down', cause)
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 🩺 DOCTORS' OPTIONS
-- ═══════════════════════════════════════════════════════════════════════════════
local function progress(label, ms)
    if GetResourceState('lxr-nui') ~= 'started' then Wait(ms) return true end
    local done = nil
    exports['lxr-nui']:Progress({ label = label, duration = ms, canCancel = true }, function(ok) done = ok end)
    while done == nil do Wait(50) end
    return done
end

CreateThread(function()
    while GetResourceState('lxr-interact') ~= 'started' do Wait(1000) end
    local I = exports['lxr-interact']
    local function sid(e) return GetPlayerServerId(NetworkGetPlayerIndexFromPed(e)) end
    I:AddGlobal('lxr-doctor:player', 'player', { label = Lang:t('ui.patient'), distance = Config.Security.maxDistance, options = {
        { label = Lang:t('ui.revive'), key = 'G', canInteract = function(e) return isDoctor() and e and Player(sid(e)).state.dead == true end,
          onSelect = function(d) local id = sid(d.entity) if progress(Lang:t('ui.reviving'), Config.Doctors.reviveMs) then TriggerServerEvent('lxr-doctor:server:revive', id) end end },
        { label = Lang:t('ui.treat'), key = 'E', canInteract = function(e) return isDoctor() and e and Player(sid(e)).state.dead ~= true end,
          onSelect = function(d)
              local id = sid(d.entity)
              local rows = {}
              for _, name in ipairs(Config.Doctors.treatItems) do
                  local n = LXRCore.Functions.HasItem(name) and 1 or 0
                  if n > 0 then rows[#rows + 1] = { id = name, name = LXRShared.Items[name].label, sub = LXRShared.Items[name].description } end
              end
              if #rows == 0 then return toast('error.no_medicine', 'error') end
              exports['lxr-nui']:Menu({ title = Lang:t('ui.treat'), rows = rows }, function(item)
                  if item and progress(Lang:t('ui.treating'), Config.Doctors.treatMs) then TriggerServerEvent('lxr-doctor:server:treat', id, item) end
              end)
          end },
    }})
    for _, o in ipairs(Config.Offices) do
        I:AddPoint('lxr-doctor:desk:' .. o.id, o.desk, { label = o.label, distance = Config.Security.promptDistance, options = {
            { label = Lang:t('ui.duty'), key = 'J', canInteract = function() return D.IsDoctor(me().job, true) end, onSelect = function() local ok, res = LXR.RPC.Server('lxr-doctor:duty', o.id) if not ok then toast('error.' .. tostring(res), 'error') end end },
        }})
        I:AddPoint('lxr-doctor:bed:' .. o.id, vector3(o.bed.x, o.bed.y, o.bed.z), { label = Lang:t('ui.bed'), distance = Config.Security.promptDistance, options = {
            { label = Lang:t('ui.lie_down', { fee = ('%.2f'):format(Config.Bed.fee) }), key = 'J', canInteract = function() return Config.Bed.enabled end, onSelect = function()
                local ok, res, extra = LXR.RPC.Server('lxr-doctor:bed', o.id)
                if not ok then return toast('error.' .. tostring(res), 'error', { amount = extra }) end
                local ped = PlayerPedId()
                SetEntityCoords(ped, res.bed.x, res.bed.y, res.bed.z, false, false, false, false) SetEntityHeading(ped, res.bed.w)
                if progress(Lang:t('ui.resting'), res.ms) then SetEntityHealth(PlayerPedId(), res.health, 0) toast('info.rested', 'success') end
            end },
        }})
        if o.blip then
            local blip = N(0x554D9D53F696D002, 1664425300, o.desk.x, o.desk.y, o.desk.z)
            if blip and blip ~= 0 then
                N(0x74F74D3207ED525C, blip, joaat('blip_shop_doctor'), true)
                N(0x9CB1A1623062F402, blip, o.label)
                if GetResourceState('lxr-mapcolor') == 'started' then pcall(function() N(0x662D364ABF16DE2F, blip, exports['lxr-mapcolor']:modifier('doctor')) end) end
                blips[#blips + 1] = blip
            end
        end
    end
end)

RegisterNetEvent('lxr:client:loaded', function() Wait(1500) TriggerServerEvent('lxr-doctor:server:ready') end)
AddEventHandler('onResourceStart', function(res) if res == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then TriggerServerEvent('lxr-doctor:server:ready') end end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then for _, b in ipairs(blips) do RemoveBlip(b) end SetEntityInvincible(PlayerPedId(), false) end end)

exports('IsDown', function() return down end)
exports('IsDoctor', isDoctor)
