# nix-agy

> agy (Gemini CLI) configuration as pure Nix. Parameterized, pkgs-free
> renderers for the autonomous agent profile.

## What you get

- **`lib.renderAutonomous`** — a pure function returning the `.gemini/`
  config files for a fully-autonomous (yolo) agent, with a caller-supplied
  residual deny list rendered as Gemini Policy Engine rules.
- **pkgs-free evaluation.** Only `lib` is needed, so image builders can call
  it without a nixpkgs instance. The Policy Engine TOML is hand-rendered for
  that reason — do not swap it for `pkgs.formats.toml`.
- **A check** asserting the emitted posture (`yolo`, Gemini's own sandbox
  off, one policy path) and that every deny entry becomes exactly one rule.

## Installation

```nix
{
  inputs.nix-agy.url = "github:dryvist/nix-agy";
}
```

## Usage

```nix
let
  render = inputs.nix-agy.lib.renderAutonomous {
    inherit (pkgs) lib;
    homeDir = "/home/agent"; # default
    residualDeny = [ "gh repo delete" "git push --force" ];
  };
in
# render.files :: home-relative path -> contents
#   ".gemini/settings.json"
#   ".gemini/policies/autonomous.toml"
render.files
```

The product name is `agy`; the CLI binary is `gemini`, so emitted paths stay
`.gemini/`.

**Autonomous profile only.** These configs assume a container is the
isolation boundary. Never render them onto a host filesystem.

## Follow-up

- Migrate the interactive home-manager module from
  `nix-ai/modules/antigravity-cli` into this repo.

## Related

- [nix-claude-code](https://github.com/dryvist/nix-claude-code) — the same
  pattern for Claude Code.
