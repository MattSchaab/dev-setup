# Agent notes

## Project-local skills go in `.agents/skills/`

When a skill from this repo creates a skill inside a project, such as
`create-verification-skill` generating `verify-<app>`, write the real files to
`.agents/skills/<name>/` in that project. Then link Claude Code to them:

```sh
mkdir -p .claude/skills
ln -s ../../.agents/skills/<name> .claude/skills/<name>
```

Codex reads `.agents/skills/` and Claude Code reads `.claude/skills/`, so one
copy serves both. The pstack skills say `.cursor/skills/`. Ignore that and use
the layout above. The vendored skills stay unmodified, so follow this rule
instead of editing their paths.

`maintain-verification-skill` looks for `.cursor/skills/verify-*/`. Look in
`.agents/skills/verify-*/` instead.
