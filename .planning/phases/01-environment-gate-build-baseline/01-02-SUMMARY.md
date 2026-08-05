---
phase: 01-environment-gate-build-baseline
plan: 02
status: complete
requirements:
  - BASE-02
  - BASE-03
key-files:
  created:
    - .planning/phases/01-environment-gate-build-baseline/baseline-report.md
  modified:
    - scripts/build-baseline.sh
    - scripts/check-x11-session.sh
---

## Plan 01-02: On-device build/install/smoke/rollback proof cycle

**Status:** Complete
**Tasks:** 2/2

### What was built

Executed `scripts/build-baseline.sh` end-to-end on a verified native-X11 session (GNOME on Xorg), completing the full D-13 cycle: gate → pin-check → fetch → build-dep → build → checksum → capture → install → smoke → rollback → verify → sanitize → report.

### Evidence captured (baseline-report.md)

- **Before (stock):** freerdp3-x11 3.15.0+dfsg-2.1+deb13u3 amd64
- **During (locally built):** freerdp3-x11 3.15.0+dfsg-2.1+deb13u3 amd64
- **After (stock restored):** freerdp3-x11 3.15.0+dfsg-2.1+deb13u3 amd64
- **Artifact:** freerdp3-x11_3.15.0+dfsg-2.1+deb13u3_amd64.deb
- **SHA-256:** b4486501e2391560958e8b010372ec4e395c48a3fa6e44a9a6f7e0e0ee7d03fc
- **Smoke test:** windowed=pass, fullscreen=pass
- **Touch device:** GXTP7386:00 27C6:0113, XITouchClass direct touch, 10 max touches
- **Display:** 2560x1600, left rotation, DPI 192
- **Stock verification:** `xfreerdp3 --version` → This is FreeRDP version 3.15.0 (n/a)

### Deviations

1. **Script permissions** — both scripts lacked execute bits (mode 644). Fixed with `chmod +x`. Committed.
2. **`--allow-downgrades`** — `apt install -y ./freerdp3-x11_*.deb` failed because the stock and locally-built packages share the same version string, so apt treated the local build as a downgrade and refused without `--allow-downgrades`. Added the flag to stage 9. Committed.

### Sanitization (D-08)

- IPv4 addresses: 0 found
- `/p:<password>` credentials: 0 found (replaced with `/p:***`)
- Launch command sanitized: `/v:HOST-IP`, `/p:***`
- Technical data preserved: versions, session/WM, rotation/scale, touchscreen model/caps, artifact path, SHA-256

### Self-Check: PASSED

- [x] baseline-report.md committed with before/during/after versions
- [x] SHA-256 checksum recorded
- [x] windowed + fullscreen pass/fail notes present
- [x] no IPv4 addresses, no credentials
- [x] stock version verified after rollback
- [x] native-X11 touchscreen identity captured (not xwayland-touch)