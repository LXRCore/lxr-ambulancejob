--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-DOCTOR — Offline tests: doctors, offices, medicine, the timer, locale parity
     Requires a sibling checkout of lxr-core (../lxr-core).
     Usage (from the lxr-doctor folder):  lua tests/run.lua [--mock out.js en|ka]
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local CORE = os.getenv('LXR_CORE_PATH') or '../lxr-core'
package.path = CORE .. '/?.lua;' .. package.path
local ok = pcall(function() require('tests.lib.fxshim') end)
if not ok then print('lxr-core shim not found at ' .. CORE .. ' (set LXR_CORE_PATH)') os.exit(2) end
local Shim = require('tests.lib.fxshim')

for _, f in ipairs({ 'shared/main.lua', 'shared/locale.lua', 'locales/en.lua', 'config.lua', 'shared/catalog.lua', 'shared/items.lua', 'shared/prices.lua', 'shared/jobs.lua' }) do Shim.load(CORE .. '/' .. f) end
Config = nil
Locale = nil
Shim.load('shared/locale.lua')
Shim.load('locales/en.lua')
Shim.load('locales/ka.lua')
Shim.load('config.lua')
Shim.load('shared/rules.lua')
local D = LXRDoctor

local passed, failed = 0, 0
local function test(name, fn)
    local okT, err = xpcall(fn, debug.traceback)
    if okT then passed = passed + 1 print('  ^ ok   ' .. name) else failed = failed + 1 print('  x FAIL ' .. name .. '\n' .. err) end
end
local function eq(a, b, msg) if a ~= b then error((msg or 'eq') .. ': expected ' .. tostring(b) .. ' got ' .. tostring(a), 2) end end

print('lxr-doctor offline tests')

test('offices name real medical jobs; every medicine is in the catalog', function()
    for _, o in ipairs(Config.Offices) do
        assert(o.desk and o.bed and o.spawn and o.label, o.id)
        for _, j in ipairs(o.jobs) do local d = LXRShared.Jobs[j] assert(d and d.type == 'medical', o.id .. ' job ' .. j) end
    end
    for _, n in ipairs(Config.Doctors.treatItems) do assert(LXRShared.Items[n], 'medicine ' .. n) assert(D.Treats(n)) end
    if Config.Doctors.reviveItem then assert(LXRShared.Items[Config.Doctors.reviveItem]) end
    assert(not D.Treats('bread'))
end)

test('who is a doctor', function()
    assert(D.IsDoctor({ name = 'valdoc', onduty = true }))
    assert(not D.IsDoctor({ name = 'valdoc', onduty = false }))
    assert(D.IsDoctor({ name = 'valdoc', onduty = false }, true))
    assert(not D.IsDoctor({ name = 'vallaw', onduty = true }))
    eq(D.OfficeFor('valdoc').id, 'valentine')
end)

test('nearest office and healing amounts', function()
    local o = D.Nearest(vector3(-300, 800, 118))
    eq(o.id, 'valentine')
    eq(D.Nearest(vector3(2400, -1370, 46)).id, 'saintdenis')
    assert(D.Heal('bandage') > 0 and D.Heal('bandage') <= 600)
    assert(D.Heal('bandage_clean') > D.Heal('bandage'))
    eq(D.Heal('bread'), 0)
end)

test('the timer', function()
    eq(D.BleedLeft(1000, 1000), Config.Death.bleedOutSeconds)
    eq(D.BleedLeft(1000, 1000 + Config.Death.bleedOutSeconds + 5), 0)
    eq(D.BleedLeft(1000, 1100), Config.Death.bleedOutSeconds - 100)
end)

test('locale parity', function()
    local en, ka = Locale.Bundles.en, Locale.Bundles.ka
    local missing = {}
    for k in pairs(en) do if ka[k] == nil then missing[#missing + 1] = k end end
    eq(#missing, 0, 'ka missing: ' .. table.concat(missing, ', '))
end)

print(('%d passed, %d failed'):format(passed, failed))

if arg and arg[1] == '--mock' and arg[2] then
    Config.Lang = arg[3] or 'en'
    local msgs = { { action = 'down', payload = { seconds = Config.Death.bleedOutSeconds }, lang = Config.Lang, locale = Lang.bundle(), brand = { name = 'The Land of Wolves', theme = 'night' } }, { action = 'tick', payload = { left = 214 } } }
    local f = assert(io.open(arg[2], 'w'))
    f:write('window.__LXR_MOCK__ = ' .. json.encode(msgs) .. ';\n')
    f:close()
    print('mock written to ' .. arg[2])
end
os.exit(failed == 0 and 0 or 1)
