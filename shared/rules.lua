--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-DOCTOR — Shared rules: who is a doctor, where the nearest office is
     ═══════════════════════════════════════════════════════════════════════════
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

LXRDoctor = LXRDoctor or {}
local D = LXRDoctor

local function typeOf(job)
    if not job or not job.name then return nil end
    if job.type then return job.type end
    local def = LXRShared.Jobs and LXRShared.Jobs[job.name]
    return def and def.type
end

function D.IsDoctor(job, ignoreDuty)
    local t = typeOf(job)
    if not t then return false end
    local ok = false
    for _, x in ipairs(Config.Doctors.jobTypes) do if x == t then ok = true end end
    if not ok then return false end
    if Config.Doctors.onDutyOnly and not ignoreDuty and not job.onduty then return false end
    return true
end

function D.Office(id) for _, o in ipairs(Config.Offices) do if o.id == id then return o end end end
function D.OfficeFor(jobName)
    for _, o in ipairs(Config.Offices) do for _, j in ipairs(o.jobs) do if j == jobName then return o end end end
end

---Nearest office to a position (respawn point).
function D.Nearest(pos)
    local best, bd
    for _, o in ipairs(Config.Offices) do
        local d = #(vector3(pos.x, pos.y, pos.z) - vector3(o.spawn.x, o.spawn.y, o.spawn.z))
        if not bd or d < bd then best, bd = o, d end
    end
    return best, bd
end

---Is this item medicine a doctor may apply to someone else.
function D.Treats(item)
    for _, n in ipairs(Config.Doctors.treatItems) do if n == item then return LXRShared.Items[n] ~= nil end end
    return false
end

---Health gained from a treat item (the catalog's effect, capped to the 600 scale).
function D.Heal(item)
    local def = LXRShared.Items[item]
    local h = def and def.effects and tonumber(def.effects.health) or 0
    return math.max(0, math.min(100, h)) * 6   -- catalog effects are 0–100, ped health is 0–600
end

---Seconds left before a downed character may give up (shorter when no doctor is on duty).
function D.BleedLeft(diedAt, now, doctorsOnDuty)
    local wait = (doctorsOnDuty ~= nil and doctorsOnDuty == 0 and Config.Death.bleedOutNoDoctors) or Config.Death.bleedOutSeconds
    return math.max(0, wait - (now - diedAt))
end

---Body part for a damage bone id (nil when unknown).
function D.PartOf(bone) return D.Bones and D.Bones[tonumber(bone) or -1] or nil end

---A blank injury record.
function D.NoInjuries() return { parts = {}, bleed = 0 } end

---Is anything wrong.
function D.Hurt(inj)
    if type(inj) ~= 'table' then return false end
    if (tonumber(inj.bleed) or 0) > 0 then return true end
    for _, v in pairs(inj.parts or {}) do if (tonumber(v) or 0) > 0 then return true end end
    return false
end

---Worst leg state (0 fine, 1 injured, 2 broken) → move rate.
function D.MoveRate(inj)
    local p = type(inj) == 'table' and inj.parts or {}
    local worst = math.max(tonumber(p.left_leg) or 0, tonumber(p.right_leg) or 0)
    if worst >= 2 then return Config.Injuries.moveRate.broken end
    if worst == 1 then return Config.Injuries.moveRate.injured end
    return 1.0
end
