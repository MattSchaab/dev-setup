# dev-setup

Skills I use with my coding agents, plus a script to install them.

| Skill | What it does | Source |
|---|---|---|
| `grilling` | Stress-tests a plan or decision by interviewing you round by round | [mattpocock/skills](https://github.com/mattpocock/skills/tree/main/skills/productivity/grilling) |
| `how` | Explains how a subsystem works; answers placement and layering questions | [pstack](https://github.com/cursor/plugins/tree/main/pstack/skills/how) |
| `why` | Digs up design rationale from git, issues, docs, chat, and observability | [pstack](https://github.com/cursor/plugins/tree/main/pstack/skills/why) |
| `teach` | Runs `how` and `why` and weaves them into one plain explanation | [pstack](https://github.com/cursor/plugins/tree/main/pstack/skills/teach) |
| `unslop` | Cuts AI tells out of writing | [pstack](https://github.com/cursor/plugins/tree/main/pstack/skills/unslop) |

I did not write any of these. They are vendored unmodified from two upstream
collections — see [credits](#credits-and-licensing).

## Install

```sh
./install.sh
```

That prompts for the agent, then for which skills. Both can be given as
arguments instead:

```sh
./install.sh claude              # every skill into Claude Code
./install.sh codex why how       # two skills into Codex
./install.sh both grilling       # one skill into both
./install.sh --list              # what's in the repo and where it's installed
./install.sh --uninstall claude  # remove the links again
```

Skills are **symlinked**, not copied, so a `git pull` here updates every agent
at once and editing an installed skill edits the repo. Re-running is safe.

## Where they land

| Agent | Directory |
|---|---|
| Claude Code | `~/.claude/skills/` |
| Codex | `~/.agents/skills/` |

Codex also still reads the deprecated `~/.codex/skills/`; this script targets
the current path. Both agents read the same `SKILL.md` format, so the skills
are installed as-is with no conversion.

The script only ever manages symlinks that point into this repo. If a real
directory already sits at a target path, it says so and leaves it untouched
rather than overwriting it — and `--uninstall` will not delete anything it did
not create.

## Credits and licensing

Every skill in this repo was written by someone else and is copied here
unmodified. Credit where it is due:

| Upstream | Author | Skills | License |
|---|---|---|---|
| [mattpocock/skills](https://github.com/mattpocock/skills) | Matt Pocock | `grilling` | MIT — [`licenses/mattpocock-skills-MIT.txt`](licenses/mattpocock-skills-MIT.txt) |
| [pstack](https://github.com/cursor/plugins/tree/main/pstack) | Lauren Tan | `how`, `why`, `teach`, `unslop` | MIT — [`licenses/pstack-MIT.txt`](licenses/pstack-MIT.txt) |

Both upstream licenses are reproduced verbatim in `licenses/`, and each keeps
its own copyright notice. The skills stay under those licenses. Nothing in this
repo relicenses them or claims authorship of them.

This is my personal setup repo, so it carries no license of its own — only
`install.sh` and this README are mine. If you want these skills, take them from
the upstreams above rather than from here; they are maintained there and this
copy will drift.
