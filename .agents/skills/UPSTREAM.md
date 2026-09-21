# Vendored skills — upstream sources

Skills under `.agents/skills/` are copies of third-party repositories. This file records
where each came from so "update to the latest" does not require rediscovering the source.

## swiftui-expert-skill

- Upstream: https://github.com/AvdLee/SwiftUI-Agent-Skill
- Canonical path in that repo: `skills/swiftui-expert-skill/`
- Vendored version: **5.1.0** (synced 2026-09-21; previously 2.0.0)

We take `SKILL.md`, `references/` and `scripts/`. We deliberately skip `assets/`
(logo images) and `agents/openai.yaml` (packaging for other agent tools) — neither is
used by Claude Code, and `assets/` is ~430K of PNGs.

To re-sync:

```sh
git clone --depth 1 https://github.com/AvdLee/SwiftUI-Agent-Skill.git /tmp/swiftui-skill-upstream
UP=/tmp/swiftui-skill-upstream/skills/swiftui-expert-skill
rsync -a --delete "$UP/references/" .agents/skills/swiftui-expert-skill/references/
rsync -a --delete "$UP/scripts/"    .agents/skills/swiftui-expert-skill/scripts/
cp "$UP/SKILL.md" .agents/skills/swiftui-expert-skill/SKILL.md
```

Then bump the version above. Local edits to the skill are not expected — make them
upstream instead, or they are lost on the next sync.
