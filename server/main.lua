--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-DOCTOR — Server: death, the timer, revives, treatment, the bed
     ═══════════════════════════════════════════════════════════════════════════
     The client only reports "I went down"; the server stamps the time,
     marks the character dead in core metadata (survives relogs), tells
     dispatch, and decides every way back: a doctor's revive, the office
     bed, or the timer and the fee.
     ═══════════════════════════════════════════════════════════════════════════
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local LXRCore = exports['lxr-core']:GetCoreObject()
local LXR = exports['lxr-core']:GetLXR()
local D = LXRDoctor
local Inventory = LXRCore.Inventory
local RES = GetCurrentResourceName()
local diedAt = {}      -- src → os.time()
local buckets = {}

local function limited(src)
    local b = buckets[src]
    local now = GetGameTimer()
    if not b or now - b.at > Config.Security.rateLimit.windowMs then b = { at = now, n = 0 } buckets[src] = b end
    b.n = b.n + 1
    return b.n > Config.Security.rateLimit.burst
end
local function player(src) return LXRCore.Functions.GetPlayer(src) end
local function notify(src, key, kind, vars) LXRCore.Notify(src, Lang:t(key, vars), kind or 'info') end
local function near(a, b, dist)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    return pa ~= 0 and pb ~= 0 and #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= (dist or Config.Security.maxDistance)
end
local function nearCoords(src, c, dist)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - vector3(c.x, c.y, c.z)) <= (dist or Config.Security.maxDistance)
end
local function nameOf(P) local ci = P.PlayerData.charinfo return ci.firstname .. ' ' .. ci.lastname end
local function log(msg, data) if Config.Debug.log then LXRCore.Log.info('doctor', msg, data) end end
local function doctorsOnDuty()
    local n = 0
    for _, P in pairs(LXRCore.Players) do if D.IsDoctor(P.PlayerData.job) then n = n + 1 end end
    return n
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ☠️ DOWN
-- ═══════════════════════════════════════════════════════════════════════════════
local function setDead(P, dead, reason)
    local src = P.PlayerData.source
    P.Functions.SetMetaData('isdead', dead == true)
    Player(src).state:set('dead', dead == true, true)
    if dead then
        diedAt[src] = os.time()
        Player(src).state:set('diedAt', diedAt[src], true)
        LXRCore.Emit('lxr:player:died', nil, src, reason)
    else
        diedAt[src] = nil
        Player(src).state:set('diedAt', false, true)
        LXRCore.Emit('lxr:player:revived', nil, src, reason)
    end
end

RegisterNetEvent('lxr-doctor:server:down', function(cause)
    local src = source
    if limited(src) then return end
    local P = player(src)
    if not P or P.PlayerData.metadata.isdead then return end
    setDead(P, true, tostring(cause or 'unknown'))
    TriggerClientEvent('lxr-doctor:client:down', src, Config.Death.bleedOutSeconds, diedAt[src])
    log('down', { source = src, cause = cause })
    if Config.Death.callDoctors and GetResourceState('lxr-dispatch') == 'started' then
        if not Config.Death.callOnlyIfOnDuty or doctorsOnDuty() > 0 then
            exports['lxr-dispatch']:Raise({ kind = 'wounded', coords = GetEntityCoords(GetPlayerPed(src)), title = Lang:t('call.wounded', { name = nameOf(P) }), src = src })
        end
    end
end)

-- giving up: only after the timer, at the nearest office, for the fee
LXR.RPC.Register('lxr-doctor:respawn', function(src)
    if limited(src) then return false, 'rate' end
    local P = player(src)
    if not P or not P.PlayerData.metadata.isdead then return false, 'not_dead' end
    local left = D.BleedLeft(diedAt[src] or 0, os.time())
    if left > 0 then return false, 'too_soon', left end
    local office = D.Nearest(GetEntityCoords(GetPlayerPed(src)))
    if not office then return false, 'invalid' end
    local fee = Config.Death.respawnFee
    if fee > 0 then
        if not P.Functions.RemoveMoney(Config.Death.respawnAccount, fee, 'doctor:bed') then
            if not (Config.Death.respawnFallback and P.Functions.RemoveMoney(Config.Death.respawnFallback, fee, 'doctor:bed')) then fee = 0 end   -- the county pays for paupers
        end
    end
    if Config.Death.dropWeaponsOnRespawn and GetResourceState('lxr-weapons') == 'started' then exports['lxr-weapons']:Disarm(src, 'death') end
    setDead(P, false, 'respawn')
    log('respawn', { source = src, office = office.id, fee = fee })
    return true, { spawn = { x = office.spawn.x, y = office.spawn.y, z = office.spawn.z, w = office.spawn.w }, health = Config.Death.respawnHealth, fee = fee, label = office.label }
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 🩺 DOCTORS
-- ═══════════════════════════════════════════════════════════════════════════════
local function pair(src, targetId)
    if limited(src) then return nil, nil, 'rate' end
    local Dr = player(src)
    if not Dr or not D.IsDoctor(Dr.PlayerData.job) then return nil, nil, 'not_doctor' end
    local T = player(tonumber(targetId) or -1)
    if not T or T.PlayerData.source == src then return nil, nil, 'invalid' end
    if not near(src, T.PlayerData.source) then return nil, nil, 'too_far' end
    return Dr, T
end

-- the doctor's client runs the progress bar first, then reports here
RegisterNetEvent('lxr-doctor:server:revive', function(targetId)
    local src = source
    local Dr, T, why = pair(src, targetId)
    if not Dr then return notify(src, 'error.' .. why, 'error') end
    if not T.PlayerData.metadata.isdead then return notify(src, 'error.not_down', 'error') end
    local item = Config.Doctors.reviveItem
    if item and not Dr.Functions.RemoveItem(item, 1, nil, 'revive') then return notify(src, 'error.no_item', 'error', { item = LXRShared.Items[item] and LXRShared.Items[item].label or item }) end
    setDead(T, false, 'revived')
    TriggerClientEvent('lxr-doctor:client:revive', T.PlayerData.source, Config.Death.reviveHealth)
    notify(src, 'info.revived', 'success', { name = nameOf(T) })
    notify(T.PlayerData.source, 'info.you_revived', 'inform', { name = nameOf(Dr) })
    log('revive', { source = src, target = T.PlayerData.source })
end)

RegisterNetEvent('lxr-doctor:server:treat', function(targetId, item)
    local src = source
    local Dr, T, why = pair(src, targetId)
    if not Dr then return notify(src, 'error.' .. why, 'error') end
    if T.PlayerData.metadata.isdead then return notify(src, 'error.is_down', 'error') end
    if not D.Treats(item) then return notify(src, 'error.invalid', 'error') end
    if not Dr.Functions.RemoveItem(item, 1, nil, 'treat') then return notify(src, 'error.no_item', 'error', { item = LXRShared.Items[item].label }) end
    local heal = D.Heal(item)
    TriggerClientEvent('lxr-doctor:client:heal', T.PlayerData.source, heal)
    notify(src, 'info.treated', 'success', { name = nameOf(T), item = LXRShared.Items[item].label })
    notify(T.PlayerData.source, 'info.you_treated', 'inform', { name = nameOf(Dr) })
    LXRCore.Emit('lxr:doctor:treated', nil, T.PlayerData.source, src, item, heal)
end)

-- duty at the office desk
LXR.RPC.Register('lxr-doctor:duty', function(src, officeId)
    if limited(src) then return false, 'rate' end
    local P, o = player(src), D.Office(officeId)
    if not P or not o or not D.IsDoctor(P.PlayerData.job, true) then return false, 'not_doctor' end
    if not nearCoords(src, o.desk) then return false, 'too_far' end
    P.Functions.SetJobDuty(not P.PlayerData.job.onduty)
    notify(src, P.PlayerData.job.onduty and 'info.on_duty' or 'info.off_duty', 'inform')
    return true, P.PlayerData.job.onduty
end)

-- the bed: treatment for a fee when no doctor is about
LXR.RPC.Register('lxr-doctor:bed', function(src, officeId)
    if limited(src) then return false, 'rate' end
    local P, o = player(src), D.Office(officeId)
    if not P or not o or not Config.Bed.enabled then return false, 'invalid' end
    if not nearCoords(src, o.bed) then return false, 'too_far' end
    if not Config.Bed.whenDoctorsOnDuty then
        for _, j in ipairs(o.jobs) do if #LXRCore.Functions.GetPlayersOnDuty(j) > 0 then return false, 'doctor_on_duty' end end
    end
    if Config.Bed.fee > 0 and not P.Functions.RemoveMoney('cash', Config.Bed.fee, 'doctor:bed') then return false, 'no_money', Config.Bed.fee end
    if P.PlayerData.metadata.isdead then setDead(P, false, 'bed') TriggerClientEvent('lxr-doctor:client:revive', src, Config.Bed.health) end
    return true, { health = Config.Bed.health, ms = Config.Bed.ms, bed = { x = o.bed.x, y = o.bed.y, z = o.bed.z, w = o.bed.w } }
end)

-- relog while dead: keep them down with the time they had left
RegisterNetEvent('lxr-doctor:server:ready', function()
    local src = source
    local P = player(src)
    if not P then return end
    if P.PlayerData.metadata.isdead then
        diedAt[src] = diedAt[src] or (os.time() - Config.Death.bleedOutSeconds)   -- a relog is not a shortcut, but the timer is not restarted either
        Player(src).state:set('dead', true, true)
        TriggerClientEvent('lxr-doctor:client:down', src, D.BleedLeft(diedAt[src], os.time()), diedAt[src])
    else
        Player(src).state:set('dead', false, true)
    end
end)

AddEventHandler('playerDropped', function() buckets[source] = nil end)
CreateThread(function() if Config.Debug.printBanner then print(('^1[lxr-doctor]^7 v%s — %d offices, bleed-out %ds, bed $%.2f'):format(GetResourceMetadata(RES, 'version', 0), #Config.Offices, Config.Death.bleedOutSeconds, Config.Bed.fee)) end end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 📤 EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════════
exports('IsDead', function(src) local P = player(src) return P ~= nil and P.PlayerData.metadata.isdead == true end)
exports('Revive', function(src, health)
    local P = player(tonumber(src))
    if not P then return false end
    local ok, err = xpcall(function()
        setDead(P, false, 'export')
        TriggerClientEvent('lxr-doctor:client:revive', P.PlayerData.source, tonumber(health) or Config.Death.reviveHealth)
    end, debug.traceback)
    if not ok then LXRCore.Log.error('doctor', 'revive export failed', { source = src, error = tostring(err) }) return false end
    return true
end)
exports('Kill', function(src, reason) local P = player(src) if not P then return false end setDead(P, true, reason or 'export') TriggerClientEvent('lxr-doctor:client:down', src, Config.Death.bleedOutSeconds, diedAt[src]) return true end)
exports('DoctorsOnDuty', doctorsOnDuty)
