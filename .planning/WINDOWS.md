---
schema_version: 1
open_count: 2
waived_count: 0
fixed_count: 0
total_count: 2
last_updated: 2026-08-08T09:05:03.100Z
---

# Broken Windows Ledger

> Cross-phase defect register. `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 04 | deviation | scripts/build-release.sh |  | Post-publish interruption test deferred: background build timing-dependent in execution environment | open |  | 2026-08-08T09:05:02.756Z |  |
| 2 | 04 | deviation | scripts/build-release.sh |  | mktemp -d vs dpkg-source -x directory conflict fixed | open |  | 2026-08-08T09:05:03.100Z |  |

````json
[
  {
    "id": 1,
    "kind": "deviation",
    "phase": "04",
    "file": "scripts/build-release.sh",
    "line": null,
    "description": "Post-publish interruption test deferred: background build timing-dependent in execution environment",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-08T09:05:02.756Z",
    "resolved_at": null
  },
  {
    "id": 2,
    "kind": "deviation",
    "phase": "04",
    "file": "scripts/build-release.sh",
    "line": null,
    "description": "mktemp -d vs dpkg-source -x directory conflict fixed",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-08T09:05:03.100Z",
    "resolved_at": null
  }
]
````
