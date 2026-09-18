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

---Seconds left before a downed character may give up.
function D.BleedLeft(diedAt, now)
    return math.max(0, Config.Death.bleedOutSeconds - (now - diedAt))
end
