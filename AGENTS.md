# AGENTS.md

Docker sandbox that runs the opencode agent behind a Squid proxy with a domain allowlist. See [README.md](README.md) for the layout and [docs/](docs/) for details.

## Language

Write everything in the repository in **English**, even when the conversation is in another language:

- Code: identifiers, file names, log and error messages, prompts shown by scripts.
- Comments, in every file type (shell, Dockerfile, YAML, Squid config).
- Documentation: `README.md`, `docs/`, this file.
- Commit messages and pull request descriptions.

Exceptions: proper names and quoted external content (French dataset names, API fields, URLs).

## Code

- Shell scripts: `#!/usr/bin/env bash`, `set -euo pipefail`, a header comment with usage examples (see [opencode/scripts/setup-albert.sh](opencode/scripts/setup-albert.sh)). Check with `bash -n` and `shellcheck` when available.
- Keep comments short; explain why, not what.
- Never print or log secrets. Read them with `read -s`, pass them to `curl` through stdin (`-H @-`), write config files under `umask 077`.
- Configuration written by setup scripts goes under `~/.config` (the `opencode-config` volume) so it survives container recreation. Merge into existing files instead of overwriting them.

## Documentation

- Update the README and `docs/` in the same change as the code they describe.
- Any new outbound domain must be justified and documented; mention whether it is in [squid/allowed-domains.txt](squid/allowed-domains.txt).
- Link files with relative Markdown links.
