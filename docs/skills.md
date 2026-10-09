# Agent skills

A skill is a folder holding a `SKILL.md` file (YAML frontmatter with `name` and `description`, then instructions). opencode lists the skills it finds and loads one when its description matches the task.

opencode looks for skills in:

| Scope          | Paths                                                                                                                          |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Whole sandbox  | `~/.config/opencode/skills/<name>/SKILL.md` (on the `opencode-config` volume, survives recreation)                             |
|                | `~/.claude/skills/<name>/SKILL.md`, `~/.agents/skills/<name>/SKILL.md` (not on a volume, lost when the container is recreated) |
| One repository | `.opencode/skills/<name>/SKILL.md`, `.claude/skills/<name>/SKILL.md`, `.agents/skills/<name>/SKILL.md`                         |

Install skills in `~/.config/opencode/skills/`: they survive container recreation and the cloned repositories stay untouched.

## Recommended skills

The main source is [etalab-ia/skills](https://github.com/etalab-ia/skills): skills aligned with French public service standards (DSFR, RGAA accessibility, ANSSI security guides, data.gouv.fr APIs…). Install them globally for opencode (`-g` targets `~/.config/opencode/skills/`; without it, the skills land in the current directory):

```bash
docker compose exec sandbox npx -y skills add etalab-ia/skills -a opencode -g
```

Node.js is in the image and GitHub is in the allowlist. Add `--skill <name>` to install a single skill.

Also useful: `insee-public-data` from [InseeFrLab/opencode-onyxia](https://github.com/InseeFrLab/opencode-onyxia) (INSEE MELODI and metadata APIs, `pynsee`). It targets the [Onyxia](https://www.onyxia.sh/) platform, so some instructions do not apply in the sandbox, and its APIs are on `.insee.fr`, already in [squid/allowed-domains.txt](../squid/allowed-domains.txt).

There is no official IGN skill yet: for the Géoplateforme, use the [geocontext MCP server](mcp.md#recommended-servers).

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
