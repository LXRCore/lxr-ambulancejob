--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-DOCTOR — Locale: English (canonical)
     Developer   : iBoss21 | Brand : LXRCore | https://www.lxrcore.com
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

Locale.Register('en', {
    error = {
        not_bleeding = 'You are not bleeding.',
        rate = 'Slow down.', invalid = 'That request is not valid.', too_far = 'Get closer.', not_doctor = 'You are no doctor.', not_dead = 'You are on your feet.', not_down = 'They are on their feet.',
        is_down = 'They are down. Bring them back first.', too_soon = 'Hold on. %{n}s more.', no_item = 'You need %{item}.', no_medicine = 'You carry no medicine.', doctor_on_duty = 'A doctor is on duty. Ask them.', no_money = 'The bed costs $%{amount}.',
    },
    info = {
        revived = '%{name} is back on their feet.', you_revived = '%{name} brought you back.', treated = 'Treated %{name} with %{item}.', you_treated = '%{name} treated you.',
        on_duty = 'On duty.', off_duty = 'Off duty.', done = 'Done.',
        part_hurt = 'Your %{part} is hurt.', part_broken = 'Your %{part} is broken.', bleeding = 'You are bleeding.', bleed_stopped = 'The bleeding has stopped.', bleed_slowed = 'The bleeding slowed.', dressed = 'You feel a little better.', woke = 'You woke at %{label}. The bed cost $%{fee}.', rested = 'You feel whole again.',
    },
    call = { wounded = '%{name} is down' },
    part = { head = 'Head', torso = 'Torso', left_arm = 'Left arm', right_arm = 'Right arm', left_leg = 'Left leg', right_leg = 'Right leg' },
    command = { setinjury = 'Set an injury on a player (admin)' },
    ui = {
        patient = 'Patient', revive = 'Bring them back', reviving = 'Working on them', treat = 'Treat', treating = 'Dressing the wound', duty = 'Duty', bed = 'The bed', lie_down = 'Lie down ($%{fee})', resting = 'Resting',
        down_kicker = 'You are down', down_title = 'Bleeding out', sub_wait = 'A doctor may still reach you. Someone can carry you to a bed.', sub_can_give_up = 'You can let go and wake at the nearest doctor.',
        wait_hint = 'the wire has gone out to the doctors', give_up = 'let go',
        examine = 'Examine', injuries = 'Your injuries', bleeding = 'Bleeding', which_part = 'Which part', dressing = 'Dressing the wound', cabinet = 'Cabinet', health = 'Health %{n}%%',
        level_0 = 'sound', level_1 = 'hurt', level_2 = 'broken', bleed_0 = 'none', bleed_1 = 'a slow bleed', bleed_2 = 'bleeding badly',
    },
})
