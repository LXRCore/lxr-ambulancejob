<img src="https://raw.githubusercontent.com/LXRCore/.github/main/profile/lxrcore-logo.png" alt="LXRCore" width="72" align="left" style="margin-right:12px">

# lxr-doctor — Death, bleeding out and coming back, for LXRCore

When a character goes down they lie where they fell with a timer. A doctor
on duty can reach them (lxr-dispatch hears every fall), a stranger can drag
them to a bed, or the timer runs out and they wake in the nearest doctor's
office lighter by the fee. Doctors treat wounds with catalog medicine; the
office bed treats anyone for a price when no doctor is about. Every job of
type `medical` in the core registry is a doctor here.

![The death card](docs/img/down.png)

## What it does

* **Down** — the client notices the ped dying and reports once; the server
  stamps the time, marks `isdead` in core metadata (survives relogs), sets
  the `dead` state bag, emits `lxr:player:died` and raises a `10-52` when a
  doctor is on duty. The body stays in the wounded pose, controls off, the
  death card counts `Config.Death.bleedOutSeconds`.
* **Back** — a doctor's revive (progress bar, consumes `bandage_clean`,
  `reviveHealth`); the office bed (fee, full health, only when no doctor of
  that office is on duty); or letting go after the timer at the nearest
  office for `respawnFee` (guns leave the hands through lxr-weapons).
* **Treatment** — a doctor picks medicine from what they carry
  (`Config.Doctors.treatItems`); the catalog's `effects.health` becomes ped
  health.
* **Duty** — at the office desk. Offices carry blips.
* **Events** — `lxr:player:died (src, cause)`, `lxr:player:revived (src,
  reason)`, `lxr:doctor:treated (target, doctor, item, heal)`.

## Install

```cfg
ensure lxr-core
ensure lxr-nui
ensure lxr-inventory
ensure lxr-interact
ensure lxr-doctor
```

lxr-dispatch and lxr-weapons are used when running. No SQL.

## Configuration

`config.lua` — `Config.Lang`, `Config.Death`, `Config.Doctors`,
`Config.Offices`, `Config.Bed`, `Config.Security`.

## API

| Name | Side | Purpose |
|---|---|---|
| `IsDead(src)` · `Revive(src, health)` · `Kill(src, reason)` · `DoctorsOnDuty()` | server | other resources' hooks |
| `Player(src).state.dead / diedAt` | both | replicated state |
| `IsDown()` · `IsDoctor()` | client | local mirror |

## Licence

© 2026 iBoss21 / LXRCore — All Rights Reserved. See `LICENSE`.
