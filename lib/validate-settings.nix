# Build the hard-fail settings validator used by home-manager activation.
{
  pkgs,
  schemaFile,
  forbiddenModelNames ? (import ./settings-policy.nix).forbiddenModelNames,
  repairLegacy ? true,
  validateSchema ? false,
}:

pkgs.writeShellApplication {
  name = "validate-gemini-settings";
  runtimeInputs = [
    pkgs.jq
    pkgs.check-jsonschema
  ];
  text = ''
    export SCHEMA_FILE="${schemaFile}"
    export FORBIDDEN_MODEL_NAMES='${builtins.toJSON forbiddenModelNames}'
    export REPAIR_LEGACY="${if repairLegacy then "1" else "0"}"
    export VALIDATE_SCHEMA="${if validateSchema then "1" else "0"}"
    ${builtins.readFile ../scripts/validate-settings.sh}
  '';
}
