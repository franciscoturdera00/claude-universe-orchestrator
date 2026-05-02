---
name: poll
description: Toggle the recurring `/sync` cron. `/poll on` registers it at `7,37 * * * *`. `/poll off` deletes it. Use when the operator says "/poll on", "/poll off", "turn polling on", or "stop polling".
---

# poll

## `/poll on`

1. `CronList`. If a recurring job whose prompt is `/sync` already exists at schedule `7,37 * * * *`, do nothing.
2. Otherwise `CronCreate` with `cron: "7,37 * * * *"`, `recurring: true`, `prompt: "/sync"`.

Report: `Polling on.`

## `/poll off`

`CronList`, then `CronDelete` every recurring job whose prompt is `/sync`, `/sweep`, or `/pipeline`. Report: `Polling off.`
