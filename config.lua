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
    Discord:     https://discord.gg/GAhk8cgXe9
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
    bleedOutNoDoctors = 60,       -- … when no doctor is on duty (the gate only holds while help can come)
    wipe = { inventory = false, cash = false, keep = { 'id_card' } },   -- what waking at the office costs beyond the fee
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
-- ████████████████████████ INJURIES ══════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
-- Hits land on a body part (the game's last-damage bone → six parts). A hard enough hit hurts the part;
-- hurt twice, it breaks; a heavy hit may open a bleed. Legs slow the walk, a broken head blacks out now and
-- then, bleeding costs health per tick until it is dressed. State lives in character metadata `injuries`.
Config.Injuries = {
    enabled = true,
    hurtAt = 40,            -- health lost in one hit (0–600 scale) that hurts a part
    breakAt = 120,          -- … that breaks it outright
    bleedAt = 90,           -- … that opens a bleed (chance below)
    bleedChance = 0.6,
    bleedTickSeconds = 30,  -- a bleed costs `bleedDamage` health every tick; walking/running makes ticks come sooner
    bleedDamage = { 8, 18 },      -- minor, major
    moveRate = { injured = 0.85, broken = 0.65 },   -- legs
    blackoutEvery = 45,     -- seconds, a broken head
    healItems = {           -- what a treat item mends: parts (all | one), bleed levels it stops
        bandage = { bleed = 1, parts = 'none' }, bandage_clean = { bleed = 2, parts = 'one' },
        miracle_tonic = { bleed = 2, parts = 'all' }, leeches = { bleed = 1, parts = 'none' }, splint = { bleed = 0, parts = 'one' },
    },
    selfItems = { 'bandage', 'bandage_clean' },     -- what a character may use on themselves (a bleed only)
    parts = { 'head', 'torso', 'left_arm', 'right_arm', 'left_leg', 'right_leg' },
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
    storage = { slots = 40, weight = 200000 },   -- the office cabinet (lxr-inventory stash per office, the office's jobs)
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
