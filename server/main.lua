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
-- 🩹 INJURIES — the client says where it was hit and how hard; the server keeps the state
-- ═══════════════════════════════════════════════════════════════════════════════
local lastBleed = {}   -- src → os.time() of the last tick
local function injuriesOf(P)
    local inj = P.PlayerData.metadata.injuries
    if type(inj) ~= 'table' or type(inj.parts) ~= 'table' then inj = D.NoInjuries() end
    return inj
end
local function setInjuries(P, inj)
    P.Functions.SetMetaData('injuries', inj)
    local src = P.PlayerData.source
    Player(src).state:set('injured', D.Hurt(inj), true)
    TriggerClientEvent('lxr-doctor:client:injuries', src, inj)
end
RegisterNetEvent('lxr-doctor:server:hurt', function(bone, loss)
    local src = source
    if limited(src) or not Config.Injuries.enabled then return end
    local P = player(src)
    if not P or P.PlayerData.metadata.isdead then return end
    loss = math.floor(tonumber(loss) or 0)
    if loss < Config.Injuries.hurtAt or loss > 600 then return end
    local part = D.PartOf(bone) or 'torso'
    local inj = injuriesOf(P)
    local was = tonumber(inj.parts[part]) or 0
    local now = was
    if loss >= Config.Injuries.breakAt then now = 2 elseif was < 2 then now = was + 1 end
    inj.parts[part] = now
    if loss >= Config.Injuries.bleedAt and math.random() < Config.Injuries.bleedChance then
        inj.bleed = math.max(tonumber(inj.bleed) or 0, loss >= Config.Injuries.breakAt and 2 or 1)
        lastBleed[src] = lastBleed[src] or os.time()
    end
    setInjuries(P, inj)
    if now ~= was then notify(src, now >= 2 and 'info.part_broken' or 'info.part_hurt', 'warning', { part = Lang:t('part.' .. part) }) end
    if (tonumber(inj.bleed) or 0) > 0 then notify(src, 'info.bleeding', 'warning') end
    log('hurt', { source = src, part = part, level = now, bleed = inj.bleed, loss = loss })
end)
-- the bleed tick: the client asks (it knows whether the character moved); the server decides
RegisterNetEvent('lxr-doctor:server:bleedTick', function(moved)
    local src = source
    if limited(src) then return end
    local P = player(src)
    if not P or P.PlayerData.metadata.isdead then return end
    local inj = injuriesOf(P)
    local lvl = tonumber(inj.bleed) or 0
    if lvl <= 0 then return end
    local every = Config.Injuries.bleedTickSeconds * (moved and 0.6 or 1.0)
    local last = lastBleed[src] or 0
    if os.time() - last < every then return end
    lastBleed[src] = os.time()
    TriggerClientEvent('lxr-doctor:client:heal', src, -(Config.Injuries.bleedDamage[lvl] or 8))
end)
-- mending: what an item does to an injury record; returns the record and whether anything changed
local function mend(inj, item, part)
    local rule = Config.Injuries.healItems[item]
    if not rule then return inj, false end
    local changed = false
    if (tonumber(inj.bleed) or 0) > 0 and (tonumber(rule.bleed) or 0) >= (tonumber(inj.bleed) or 0) then inj.bleed = 0 changed = true end
    if rule.parts == 'all' then
        for k, v in pairs(inj.parts) do if (tonumber(v) or 0) > 0 then inj.parts[k] = 0 changed = true end end
    elseif rule.parts == 'one' then
        local pick = part
        if not pick or (tonumber(inj.parts[pick]) or 0) == 0 then
            local worst = 0
            for k, v in pairs(inj.parts) do if (tonumber(v) or 0) > worst then worst = v pick = k end end
        end
        if pick and (tonumber(inj.parts[pick]) or 0) > 0 then inj.parts[pick] = 0 changed = true end
    end
    return inj, changed
end
-- a character dresses their own bleed
RegisterNetEvent('lxr-doctor:server:selfTreat', function(item)
    local src = source
    if limited(src) then return end
    local P = player(src)
    if not P or P.PlayerData.metadata.isdead then return end
    local allowed = false
    for _, n in ipairs(Config.Injuries.selfItems) do if n == item then allowed = true end end
    if not allowed then return end
    local inj = injuriesOf(P)
    if not P.Functions.RemoveItem(item, 1, nil, 'self treat') then return notify(src, 'error.no_item', 'error', { item = LXRShared.Items[item] and LXRShared.Items[item].label or item }) end
    local bleeding = (tonumber(inj.bleed) or 0) > 0
    if bleeding then
        local rule = Config.Injuries.healItems[item] or { bleed = 1 }
        inj.bleed = (tonumber(rule.bleed) or 0) >= (tonumber(inj.bleed) or 0) and 0 or inj.bleed
        setInjuries(P, inj)
    end
    TriggerClientEvent('lxr-doctor:client:heal', src, D.Heal(item))   -- the catalog's health effect either way
    notify(src, not bleeding and 'info.dressed' or inj.bleed == 0 and 'info.bleed_stopped' or 'info.bleed_slowed', 'success')
end)
-- a doctor looks a patient over
LXR.RPC.Register('lxr-doctor:examine', function(src, targetId)
    local Dr, T, why = (function()
        if limited(src) then return nil, nil, 'rate' end
        local Dr = player(src)
        if not Dr or not D.IsDoctor(Dr.PlayerData.job) then return nil, nil, 'not_doctor' end
        local T = player(tonumber(targetId) or -1)
        if not T or T.PlayerData.source == src then return nil, nil, 'invalid' end
        if not near(src, T.PlayerData.source) then return nil, nil, 'too_far' end
        return Dr, T
    end)()
    if not Dr then return false, why end
    local ped = GetPlayerPed(T.PlayerData.source)
    return true, { name = nameOf(T), injuries = injuriesOf(T), health = ped ~= 0 and GetEntityHealth(ped) or 0, dead = T.PlayerData.metadata.isdead == true }
end)
LXR.RPC.Register('lxr-doctor:myInjuries', function(src)
    local P = player(src)
    if not P then return false, 'invalid' end
    return true, injuriesOf(P)
end)
AddEventHandler('lxr:player:loaded', function(P)
    if P and P.PlayerData then SetTimeout(2000, function() if LXRCore.Players[P.PlayerData.source] then setInjuries(P, injuriesOf(P)) end end) end
end)

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
    local left = D.BleedLeft(diedAt[src] or 0, os.time(), doctorsOnDuty())
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
    local wipe = Config.Death.wipe or {}
    if wipe.inventory then Inventory.ClearInventory(src, wipe.keep) end
    if wipe.cash then local c = P.PlayerData.money.cash or 0 if c > 0 then P.Functions.RemoveMoney('cash', c, 'doctor:wipe') end end
    setInjuries(P, D.NoInjuries())
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
    local inj = injuriesOf(T) inj.bleed = 0 setInjuries(T, inj)
    TriggerClientEvent('lxr-doctor:client:revive', T.PlayerData.source, Config.Death.reviveHealth)
    notify(src, 'info.revived', 'success', { name = nameOf(T) })
    notify(T.PlayerData.source, 'info.you_revived', 'inform', { name = nameOf(Dr) })
    log('revive', { source = src, target = T.PlayerData.source })
end)

RegisterNetEvent('lxr-doctor:server:treat', function(targetId, item, part)
    local src = source
    local Dr, T, why = pair(src, targetId)
    if not Dr then return notify(src, 'error.' .. why, 'error') end
    if T.PlayerData.metadata.isdead then return notify(src, 'error.is_down', 'error') end
    if not D.Treats(item) then return notify(src, 'error.invalid', 'error') end
    if not Dr.Functions.RemoveItem(item, 1, nil, 'treat') then return notify(src, 'error.no_item', 'error', { item = LXRShared.Items[item].label }) end
    local heal = D.Heal(item)
    local inj, changed = mend(injuriesOf(T), item, part)
    if changed then setInjuries(T, inj) end
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

-- the office cabinet: a stash for the office's jobs
LXR.RPC.Register('lxr-doctor:cabinet', function(src, officeId)
    if limited(src) then return false, 'rate' end
    local P, o = player(src), D.Office(officeId)
    if not P or not o or not D.IsDoctor(P.PlayerData.job, true) then return false, 'not_doctor' end
    if not nearCoords(src, o.desk) then return false, 'too_far' end
    if GetResourceState('lxr-inventory') ~= 'started' then return false, 'invalid' end
    exports['lxr-inventory']:OpenInventory(src, 'stash', 'doctor-' .. o.id, { label = o.label, job = o.jobs, slots = Config.Doctors.storage.slots, weight = Config.Doctors.storage.weight, coords = o.desk, distance = Config.Security.maxDistance })
    return true
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
    setInjuries(P, D.NoInjuries())
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
        TriggerClientEvent('lxr-doctor:client:down', src, D.BleedLeft(diedAt[src], os.time(), doctorsOnDuty()), diedAt[src])
    else
        Player(src).state:set('dead', false, true)
    end
end)

AddEventHandler('playerDropped', function() buckets[source] = nil lastBleed[source] = nil end)
exports('GetInjuries', function(src) local P = player(src) return P and injuriesOf(P) or nil end)
exports('SetInjuries', function(src, inj) local P = player(src) if not P then return false end setInjuries(P, type(inj) == 'table' and inj or D.NoInjuries()) return true end)
-- /setinjury id part level — testing and the admin's hand
LXRCore.Commands.Add('setinjury', Lang:t('command.setinjury'), { { name = 'id', help = 'Player id' }, { name = 'part', help = 'head | torso | left_arm | right_arm | left_leg | right_leg | bleed' }, { name = 'level', help = '0 | 1 | 2' } }, true, function(src, args)
    local P = player(tonumber(args[1]) or -1)
    if not P then return notify(src, 'error.invalid', 'error') end
    local inj = injuriesOf(P)
    if args[2] == 'bleed' then inj.bleed = math.max(0, math.min(2, tonumber(args[3]) or 0)) else inj.parts[args[2]] = math.max(0, math.min(2, tonumber(args[3]) or 0)) end
    setInjuries(P, inj)
    notify(src, 'info.done', 'success')
end, 'admin')
-- bandages used from the satchel dress your own bleed (a doctor's treat is the way to mend a part)
local function registerSelfItems()
    for _, item in ipairs(Config.Injuries.selfItems or {}) do
        if LXRShared.Items[item] then LXRCore.Items.RegisterUsable(item, function(src) TriggerClientEvent('lxr-doctor:client:selfTreat', src, item) end) end
    end
end
CreateThread(registerSelfItems)
-- lxr-hud registers every catalog item with effects (a bandage has one); ours must be the handler whatever starts last
AddEventHandler('onResourceStart', function(res) if res == 'lxr-hud' then SetTimeout(500, registerSelfItems) end end)
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
