# Agent skills

A skill is a folder holding a `SKILL.md` file (YAML frontmatter with `name` and `description`, then instructions). opencode lists the skills it finds and loads one when its description matches the task.

opencode looks for skills in:

| Scope            | Paths                                                                                                   |
| ---------------- | ------------------------------------------------------------------------------------------------------- |
| Whole sandbox    | `~/.config/opencode/skills/<name>/SKILL.md` (on the `opencode-config` volume, survives recreation)      |
| One repository   | `.opencode/skills/<name>/SKILL.md`, `.claude/skills/<name>/SKILL.md`, `.agents/skills/<name>/SKILL.md` |

Install skills in `~/.config/opencode/skills/` to keep the cloned repositories untouched.

## Recommended skills

| Skill               | Data                                                                                                     | Source                                                                                                                         | Domains used at runtime                              |
| ------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------- |
| `datagouv-apis`     | data.gouv.fr main, metrics and tabular APIs (official)                                                    | [datagouv/datagouv-skill](https://github.com/datagouv/datagouv-skill), `SKILL.md` at the root                                  | `.gouv.fr` (allowed)                                 |
| `insee-public-data` | INSEE MELODI and metadata APIs, `pynsee`, data.gouv.fr                                                     | [InseeFrLab/opencode-onyxia](https://github.com/InseeFrLab/opencode-onyxia), `.opencode/skills/insee-public-data/`            | `.insee.fr` (not allowed by default), `.gouv.fr`     |
| `geodata`           | Geometries of French communes and IRIS (IGN ADMIN EXPRESS, `geo.api.gouv.fr`), projections, choropleths | [InseeFrLab/opencode-onyxia](https://github.com/InseeFrLab/opencode-onyxia), `.opencode/skills/geodata/`                       | `.gouv.fr`, `.geopf.fr`, `.ign.fr` (allowed)         |

There is no official IGN skill yet: for the Géoplateforme, use the [geocontext MCP server](mcp.md#recommended-servers). The `insee-public-data` and `geodata` skills target the [Onyxia](https://www.onyxia.sh/) data science platform (S3 storage, Python/R): some instructions do not apply in the sandbox.

Other skills for French public services (DSFR, RGAA accessibility, ANSSI security guides…) are in [etalab-ia/skills](https://github.com/etalab-ia/skills), under `skills/<name>/`.

## Install a skill

Clone the source repository inside the sandbox and copy the skill folder (GitHub is in the allowlist):

```bash
docker compose exec sandbox sh -c '
  set -e
  dst=~/.config/opencode/skills
  tmp=$(mktemp -d)
  git clone --depth 1 https://github.com/datagouv/datagouv-skill "$tmp/datagouv"
  mkdir -p "$dst/datagouv-apis" && cp "$tmp/datagouv/SKILL.md" "$dst/datagouv-apis/"
  git clone --depth 1 https://github.com/InseeFrLab/opencode-onyxia "$tmp/insee"
  cp -r "$tmp/insee/.opencode/skills/insee-public-data" "$tmp/insee/.opencode/skills/geodata" "$dst/"
  rm -rf "$tmp"
  ls "$dst"'
```

The folder name must match the `name` field of the frontmatter. To update a skill, run the same commands again; to remove one, delete its folder.

For the `insee-public-data` skill, add `.insee.fr` to [squid/allowed-domains.txt](../squid/allowed-domains.txt) and run `docker compose restart proxy`.

`npx skills add` (the installer suggested by some repositories) also works, since the image includes Node.js; check where it writes the skill, so it ends up under `~/.config/opencode/skills/` rather than in the repository.

## Permissions

To control which skills the agent may load, add a `permission.skill` section to `~/.config/opencode/opencode.json`:

```json
{
  "permission": {
    "skill": {
      "*": "ask",
      "datagouv-apis": "allow"
    }
  }
}
```

Values: `allow` (loaded without asking), `ask` (the user confirms), `deny` (hidden from the agent). See the [opencode skills documentation](https://opencode.ai/docs/skills/).

Skills are instructions the agent follows: read a skill before installing it, as you would a script.
