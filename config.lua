--[[
    ██╗     ██╗  ██╗██████╗       ██████╗  ██████╗  ██████╗████████╗ ██████╗ ██████╗
    ██║     ╚██╗██╔╝██╔══██╗      ██╔══██╗██╔═══██╗██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗
    ██║      ╚███╔╝ ██████╔╝█████╗██║  ██║██║   ██║██║        ██║   ██║   ██║██████╔╝
    ██║      ██╔██╗ ██╔══██╗╚════╝██║  ██║██║   ██║██║        ██║   ██║   ██║██╔══██╗
    ███████╗██╔╝  ██╗██║  ██║     ██████╔╝╚██████╔╝╚██████╗   ██║   ╚██████╔╝██║  ██║
    ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═════╝  ╚═════╝  ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝

    LXR Core - Doctor

    Death, bleeding out and coming back. When a character goes down they
    lie where they fell with a timer: a doctor on duty can reach them
    (dispatch hears it), a stranger can drag them to a bed, or the timer
    runs out and they wake in the nearest doctor's office lighter by the
    fee. Doctors treat wounds with catalog medicine; the office bed treats
    anyone for a price when no doctor is about.

    Brand:       LXRCore — Lux Empire eXperience RedM Core
    Product:     wolves.land / The Land of Wolves
    Developer:   iBoss21 / LXRCore
    Website:     https://www.lxrcore.com
    Discord:     https://discord.gg/ZHMKVYyhBa (development)
    GitHub:      https://github.com/LXRCore

    Version: 3.0.0
    Performance Target: 0.00 ms idle (a 500 ms death watch; per-frame only while down)

    © 2026 iBoss21 / LXRCore | lxrcore.com | All Rights Reserved
]]

Config = Config or {}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ LANGUAGE ██████████████████████████████████████████████
-- ████████████████████████████████████████████████████████████████████████████████
Config.Lang = 'en'

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ DEATH ═════════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
Config.Death = {
    bleedOutSeconds = 300,        -- how long a downed character waits before they may give up
    reviveHealth = 200,           -- health after a doctor's revive (max 600)
    respawnHealth = 400,          -- health after waking at the office
    respawnFee = 12.50,           -- 1899: a doctor's visit with a bed was $10–15
    respawnAccount = 'cash', respawnFallback = 'bank',
    dropWeaponsOnRespawn = true,  -- guns leave the hands (they stay in the satchel)
    callDoctors = true,           -- raise a `wounded` call through lxr-dispatch
    callOnlyIfOnDuty = true,      -- no call when no doctor is on duty (the timer is the way out)
    anim = { dict = 'script_common@shared_scenarios@lying@ground@male@a@wounded@base', name = 'base' },
    controlsWhileDown = { 0x07CE1E61, 0xF84FA74F, 0xD9D0E1C0, 0x8FFC75D6, 0xD27782E3, 0xB4E465B4, 0x7065027D, 0x8FD015D8 },
}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ THE DOCTORS ═══════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
Config.Doctors = {
    jobTypes = { 'medical' },
    onDutyOnly = true,
    reviveItem = 'bandage_clean',        -- consumed on revive (nil: none)
    treatItems = { 'bandage', 'bandage_clean', 'miracle_tonic', 'leeches' },   -- catalog medicine a doctor may apply to another
    treatMs = 6000, reviveMs = 12000,
}

-- offices: duty desk and a bed. jobs: which medical jobs work here.
Config.Offices = {
    { id = 'valentine',  label = "Valentine Doctor's Office", jobs = { 'valdoc' }, desk = vector3(-286.28, 804.77, 119.30), bed = vector4(-284.49, 807.49, 119.38, 90.0), spawn = vector4(-288.79, 808.83, 119.38, 270.0), blip = true },
    { id = 'saintdenis', label = 'Saint Denis General Hospital', jobs = { 'sddoc' }, desk = vector3(2385.24, -1374.19, 46.55), bed = vector4(2382.31, -1372.55, 46.55, 0.0), spawn = vector4(2378.21, -1370.32, 45.82, 180.0), blip = true },
    { id = 'armadillo',  label = 'Armadillo Doctor',            jobs = { 'armdoc' }, desk = vector3(-3650.37, -2645.63, -13.45), bed = vector4(-3651.38, -2653.74, -13.45, 90.0), spawn = vector4(-3648.06, -2647.18, -13.46, 0.0), blip = true },
}

-- the bed: treatment for a fee when no doctor of that office is on duty (an NPC doctor)
Config.Bed = { enabled = true, fee = 3.00, health = 600, ms = 15000, whenDoctorsOnDuty = false }

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ SECURITY ══════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
Config.Security = { rateLimit = { windowMs = 2000, burst = 8 }, maxDistance = 4.0, promptDistance = 2.0 }

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ DEBUG ═════════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
Config.Debug = { printBanner = true, log = true }
