# Flake checks for settings validation.
{
  pkgs,
  validator,
  renderAutonomous,
  fixtureDeny,
}:
let
  inherit (pkgs) lib;
  render = renderAutonomous {
    inherit (pkgs) lib;
    residualDeny = fixtureDeny;
  };

  autonomousSettings = pkgs.writeText "autonomous-settings.json" render.geminiSettingsJson;

  autonomousParsed = builtins.fromJSON render.geminiSettingsJson;
  invalidSubagentSettings = pkgs.writeText "invalid-subagent-settings.json" (
    builtins.toJSON (
      autonomousParsed
      // {
        model = {
          name = "subagent";
        };
      }
    )
  );

  runValidator =
    name: target: baseline: expectSuccess: repairLegacy:
    pkgs.runCommand name
      {
        nativeBuildInputs = [ validator ];
      }
      ''
        set -euo pipefail
        export REPAIR_LEGACY="${if repairLegacy then "1" else "0"}"
        if ${validator}/bin/validate-gemini-settings "${target}" "${baseline}"; then
          rc=0
        else
          rc=1
        fi
        if [[ ${if expectSuccess then "true" else "false"} == "true" ]]; then
          [[ "$rc" -eq 0 ]] || exit 1
        else
          [[ "$rc" -ne 0 ]] || exit 1
        fi
        touch "$out"
      '';
in
{
  settings-validation-autonomous =
    runValidator "check-settings-autonomous" autonomousSettings autonomousSettings true
      false;

  settings-validation-negative-subagent =
    runValidator "check-settings-negative-subagent" invalidSubagentSettings autonomousSettings false
      false;

  settings-validation-positive-baseline =
    runValidator "check-settings-positive-baseline" autonomousSettings autonomousSettings true
      false;
}
