# Changelog

## 3.0.0 — 2026-09-19
* Injuries: hits land on body parts (bone ids from the game's own bone lists), parts get hurt or broken, heavy hits bleed; legs slow the walk, a broken head blacks out, a bleed costs health per tick until dressed. Bandages from the satchel dress a bleed; doctors examine and treat a chosen part; `/injuries`, `/setinjury`, exports `GetInjuries / SetInjuries`, state bag `injured`.
* Waking at the office: a shorter wait when no doctor is on duty; optional wipe of satchel and cash. The office cabinet (lxr-inventory stash per office).
* Fix: `LXRCore.PlayerData` stays current — the core object comes back as a copy, so cash, job and metadata never changed after login in this resource. It now listens to `lxr:client:data` / `lxr:client:unloaded` and refreshes its copy.
* LXRCore v3 release line: every resource ships as 3.0.0 from here (the entries below are the road to it).

## 3.0.0 — 2026-09-18

Rebuilt on the LXRCore v3 native API (repository renamed from lxr-ambulancejob). Nothing of the earlier build remains; office positions were kept as data.

* Server-owned death: bleed-out timer, wounded pose, controls off, relog-safe
* Revive and treatment by every registry medical job with catalog medicine; office beds for a fee; duty
* Dispatch hears every fall; lxr-weapons drops the hands on death
* Death card on the LXR UI Kit, locales EN / KA, offline tests
