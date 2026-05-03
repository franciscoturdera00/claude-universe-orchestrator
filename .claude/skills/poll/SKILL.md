---
name: poll
description: Toggle the recurring `/sync` cron. `/poll on` registers it at 30-minute intervals starting 10 minutes after activation. `/poll off` deletes it. Use when the operator says "/poll on", "/poll off", "turn polling on", or "stop polling".
---

# poll

## `/poll on`

The schedule fires every 30 minutes, with the first fire 10 minutes after activation. Compute the cron from the current local minute:

- `m1 = (now.minute + 10) % 60`
- `m2 = (m1 + 30) % 60`
- Cron: `<min(m1,m2)>,<max(m1,m2)> * * * *`

Steps:

1. `CronList`. Identify any existing recurring job whose prompt is `/sync`.
2. `CronDelete` it (so the schedule resets relative to *this* activation, not the previous one).
3. Get the local minute: `date "+%M"`.
4. Compute `m1` and `m2` as above and assemble the cron string.
5. `CronCreate` with that cron, `recurring: true`, `prompt: "/sync"`.

Report: `Polling on. /sync at :<m1>,:<m2> every hour (first fire ~10 min from now).`

## `/poll off`

`CronList`, then `CronDelete` every recurring job whose prompt is `/sync`, `/sweep`, or `/pipeline`. Report: `Polling off.`
