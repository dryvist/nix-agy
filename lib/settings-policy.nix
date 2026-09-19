# pkgs-free policy constants for Gemini CLI / agy settings validation.
{
  schemaUrl = "https://raw.githubusercontent.com/google-gemini/gemini-cli/main/schemas/settings.schema.json";

  # LiteLLM local-proxy role names. agy validates model.name against its own
  # registry at load time; these router aliases are rejected and cause the
  # entire settings file to be discarded — not just the model key.
  forbiddenModelNames = [
    "subagent"
    "lead"
    "judge"
    "cheap"
  ];

  # Hard-fail a settings attrset that names a router role as model.name.
  # Pure Nix: fires at evaluation time via `assert`, no shell involved. No
  # renderer in this repo currently produces a `model` key — this predicate
  # exists for a settings attrset supplied by a future/downstream consumer.
  assertModelName =
    forbiddenModelNames: settings:
    assert !(builtins.elem (settings.model.name or null) forbiddenModelNames);
    settings;
}
