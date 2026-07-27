# nix-agy - AI Agent Instructions

All agy / Gemini-CLI-specific Nix config. Stranger-consumable: every input is
a function argument, nothing homelab-specific is baked in.

## Critical constraints

1. **`lib/render-autonomous.nix` stays pkgs-free.** Only `lib`. The Policy
   Engine TOML is hand-rendered because of this — do not "improve" it into
   `pkgs.formats.toml`.
2. **Byte-compatible with `nix-ai`'s gemini render** while both exist.
   Changing whitespace or the generated-by header breaks that.
3. **Autonomous profile is container-only.** No home-manager code path may
   render it onto a host filesystem.
4. **Paths are `.gemini/`**, not `.agy/` — the CLI binary is `gemini`.
5. **git-flow**: feature branches off `develop`; `main` is the release branch.
   Conventional-commit subjects only.

## Validation

```bash
nix flake check
nix fmt
```

## Follow-up

- Migrate the interactive module from `nix-ai/modules/antigravity-cli` here.
