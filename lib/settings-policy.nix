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
}
