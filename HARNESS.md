# HARNESS.md: ea-nginx (CPANEL-57111)

The harness protects one failure: editing `SOURCES/cpanel/` without regenerating
`SOURCES/cpanel.tar.gz`. The package ships the tarball, so a stale one ships old
config and no test fails. A second artifact simplifies the other routine job, the
nginx version bump, by putting its steps in one place.

## Tree

    .claude
    ├── hook.log
    ├── hooks
    │   └── check-cpanel-tar.sh
    ├── settings.json
    └── skills
        └── ea-nginx-version-bump
            └── SKILL.md

plus `CLAUDE.md` at the repo root

## Seven-component audit

| Component | Artifact | Rationale |
|---|---|---|
| Context engineering | `CLAUDE.md` | Commands, architecture, release rules; trimmed after `/init` over-claimed. |
| Tool surface | empty | No MCP, subagents or extra tools; the repo needs only Bash and file edits. |
| Control flow | `SKILL.md` | A nine-step ordered bump procedure, run only on request. |
| Quality gates | `check-cpanel-tar.sh` | Diffs the tarball against `SOURCES/cpanel/` after every Write/Edit. |
| Reliability/safety | `disable-model-invocation` in `SKILL.md` | Bump touches spec and binaries, so it never auto-starts. The hook only warns. |
| Observability | `hook.log` | One line per hook call: time, tool, path, fired/quiet. |
| Effectiveness levers | empty | No model/effort settings or evals; nothing measured yet. |

Five components have artifacts, two are empty.

## Is the imbalance defensible?

Defensible. The repo has one silent failure and one repeatable procedure, so the
harness is a gate and a procedure. Effectiveness is the weak spot: nothing shows
whether the harness helps, only that it works.

## Rejected choice: regenerate the tarball in the hook

I considered having the hook run `./update_cpanel_tar` instead of warning. It would
remove the step entirely. I rejected it because the script also runs `git add` on
the tarball, so a hook would stage files without being asked. It would also rebuild
after every edit during a multi-file change. The warning lets Claude finish the
edits and regenerate once. The cost is real: the warning can be ignored.

## Would I notice if it disappeared?

- `check-cpanel-tar.sh`: yes. The stale tarball could ship unnoticed.
- `SKILL.md`: yes, in the next bump. The steps would be scattered again.
- `CLAUDE.md`: yes. Test commands and `SPEC=` were all verified true.
- `hook.log`: no. It exists as evidence. I would leave it untracked.
- CLAUDE.md's release section overlaps the skill. Kept: rules vs. order and checks.

## Cross-artifact reference

`SKILL.md` ends: "Do not edit `SOURCES/cpanel/` in this workflow. If you do, the
PostToolUse hook will say whether the tarball needs `./update_cpanel_tar`."

The skill leaves tarball staleness to the hook and keeps to the version bump. If
the hook were removed, this sentence would point at nothing.

## Verification
- Hook fired on a real Edit of `cache.json` (tarball stale), stayed quiet after
  `./update_cpanel_tar`, and stayed quiet for `README.md`. Four real log lines.
- Skill steps run by hand in a scratch worktree for nginx 1.31.7: patch applied,
  `prove t/` passed (428 tests). Not invoked as `/ea-nginx-version-bump`.

## Falsified claim

I claimed the hook guards against a stale tarball. It does not when the edit is made
through Bash. The matcher is `Write|Edit`, so a `sed -i` on
`SOURCES/cpanel/ea-nginx/cache.json` changed the file, logged nothing (log stayed at
4 lines) and left the tarball stale. The hook guards Claude's edit tools, not the
directory. Fix options: add `Bash` to the matcher (noisy, every command logs) or
run the same diff as a git pre-commit check. Not applied.

Earlier I also predicted `/init` would miss the `update_cpanel_tar` step. It did not.
