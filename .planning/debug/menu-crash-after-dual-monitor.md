---
status: investigating
trigger: "scripts/menu crashes after choosing option 3 and entering the RDP password while testing the new dual-monitor X11 launcher"
created: 2026-09-07
updated: 2026-09-07
---

# Debug: menu crash after dual-monitor launch

## Symptoms

DATA_START
- Expected: `./scripts/menu` option 3 starts the RDP session across the OneMix panel and external display.
- Actual: after choosing option 3 and entering the RDP password, the launch crashes and returns to the TTY.
- Error output: not captured; user asked the agent to inspect local evidence.
- Timeline: began after the dual-monitor launcher changes; the prior one-monitor launcher worked.
- Reproduction: run `./scripts/menu`, choose `3`, enter the RDP password.
DATA_END

## Current Focus

- hypothesis: The launch fails in the new private-X-server display-layout path or in a dependent X11/RDP process after password entry.
- test: Gather process, Xorg, startx, and launcher evidence; compare the dual-monitor changes with the prior launcher behavior.
- expecting: A concrete failing command or log entry that distinguishes output validation/layout failure from Xorg or FreeRDP failure.
- next_action: gather initial evidence

## Evidence

- timestamp: 2026-09-07
  observation: Automated launcher fixtures, shell syntax checking, and whitespace checking passed before the physical test.
- timestamp: 2026-09-07
  observation: The agent shell is currently a TTY with no DISPLAY; a prior scan saw no running Xorg or xfreerdp3 process after the reported crash.

## Eliminated

- hypothesis: none yet

## Resolution

- root_cause:
- fix:
- verification:
- files_changed:
