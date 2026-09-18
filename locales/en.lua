--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-DOCTOR — Locale: English (canonical)
     Developer   : iBoss21 | Brand : LXRCore | https://www.lxrcore.com
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

Locale.Register('en', {
    error = {
        rate = 'Slow down.', invalid = 'That request is not valid.', too_far = 'Get closer.', not_doctor = 'You are no doctor.', not_dead = 'You are on your feet.', not_down = 'They are on their feet.',
        is_down = 'They are down. Bring them back first.', too_soon = 'Hold on. %{n}s more.', no_item = 'You need %{item}.', no_medicine = 'You carry no medicine.', doctor_on_duty = 'A doctor is on duty. Ask them.', no_money = 'The bed costs $%{amount}.',
    },
    info = {
        revived = '%{name} is back on their feet.', you_revived = '%{name} brought you back.', treated = 'Treated %{name} with %{item}.', you_treated = '%{name} treated you.',
        on_duty = 'On duty.', off_duty = 'Off duty.', woke = 'You woke at %{label}. The bed cost $%{fee}.', rested = 'You feel whole again.',
    },
    call = { wounded = '%{name} is down' },
    ui = {
        patient = 'Patient', revive = 'Bring them back', reviving = 'Working on them', treat = 'Treat', treating = 'Dressing the wound', duty = 'Duty', bed = 'The bed', lie_down = 'Lie down ($%{fee})', resting = 'Resting',
        down_kicker = 'You are down', down_title = 'Bleeding out', sub_wait = 'A doctor may still reach you. Someone can carry you to a bed.', sub_can_give_up = 'You can let go and wake at the nearest doctor.',
        wait_hint = 'the wire has gone out to the doctors', give_up = 'let go',
    },
})
