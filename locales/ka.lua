--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-DOCTOR — Locale: Georgian (ქართული)
     Developer   : iBoss21 | Brand : LXRCore | https://www.lxrcore.com
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

Locale.Register('ka', {
    error = {
        rate = 'შენელდი.', invalid = 'მოთხოვნა არასწორია.', too_far = 'მიუახლოვდი.', not_doctor = 'ექიმი არ ხარ.', not_dead = 'ფეხზე დგახარ.', not_down = 'ის ფეხზე დგას.',
        is_down = 'ის დაცემულია. ჯერ გამოაცოცხლე.', too_soon = 'მოითმინე. კიდევ %{n}წმ.', no_item = 'გჭირდება: %{item}.', no_medicine = 'წამალი თან არ გაქვს.', doctor_on_duty = 'ექიმი მორიგეობაზეა. მას მიმართე.', no_money = 'საწოლი ღირს $%{amount}.',
    },
    info = {
        revived = '%{name} ისევ ფეხზეა.', you_revived = '%{name}-მა გამოგაცოცხლა.', treated = '%{name} განიკურნა: %{item}.', you_treated = '%{name}-მა გიმკურნალა.',
        on_duty = 'მორიგეობაზე ხარ.', off_duty = 'მორიგეობა დამთავრდა.', woke = 'გამოფხიზლდი: %{label}. საწოლი დაჯდა $%{fee}.', rested = 'ისევ მთელი ხარ.',
    },
    call = { wounded = '%{name} დაცემულია' },
    ui = {
        patient = 'პაციენტი', revive = 'გამოცოცხლება', reviving = 'მუშაობს', treat = 'მკურნალობა', treating = 'ჭრილობის შეხვევა', duty = 'მორიგეობა', bed = 'საწოლი', lie_down = 'დაწექი ($%{fee})', resting = 'ისვენებ',
        down_kicker = 'დაცემული ხარ', down_title = 'სისხლი გდის', sub_wait = 'ექიმი ჯერ კიდევ შეიძლება მოვიდეს. ვინმეს საწოლამდე მიყვანა შეუძლია.', sub_can_give_up = 'შეგიძლია გაუშვა და უახლოეს ექიმთან გამოფხიზლდე.',
        wait_hint = 'დეპეშა ექიმებთან წავიდა', give_up = 'გაშვება',
    },
})
