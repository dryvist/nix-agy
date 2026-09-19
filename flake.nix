{
  description = "agy (Gemini CLI) configuration as pure Nix — autonomous-profile renderers for agent container images.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    gemini-cli = {
      url = "github:google-gemini/gemini-cli";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      gemini-cli,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      schemaFile = "${gemini-cli}/schemas/settings.schema.json";

      settingsPolicy = import ./lib/settings-policy.nix;

      # Fixture deny list for the check. Consumers pass their own; this only
      # has to exercise the renderer.
      fixtureDeny = [
        "gh repo delete"
        "gh secret"
        "git push --force"
      ];
    in
    {
      lib = {
        inherit settingsPolicy;
        renderAutonomous = import ./lib/render-autonomous.nix;
      };

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            git
            jq
            nixfmt-tree
            check-jsonschema
          ];
        };
      });

      checks = forAllSystems (
        pkgs:
        let
          render = self.lib.renderAutonomous {
            inherit (pkgs) lib;
            residualDeny = fixtureDeny;
          };
          validationChecks = import ./lib/checks.nix { inherit pkgs settingsPolicy; };
        in
        {
          autonomous-profile-render =
            pkgs.runCommand "autonomous-profile-render"
              {
                nativeBuildInputs = [
                  pkgs.jq
                  pkgs.check-jsonschema
                ];
                inherit (render) geminiPolicyToml;
                geminiSettings = render.geminiSettingsJson;
                passAsFile = [
                  "geminiSettings"
                  "geminiPolicyToml"
                ];
              }
              ''
                set -euo pipefail

                check-jsonschema --schemafile "${schemaFile}" "$geminiSettingsPath"

                # Own sandbox off, policy referenced, auth pinned so a
                # headless run does not stop at the interactive picker.
                jq -e '.tools.sandbox == false' "$geminiSettingsPath"
                jq -e '.policyPaths | length == 1' "$geminiSettingsPath"
                jq -e '.security.auth.selectedType == "oauth-personal"' "$geminiSettingsPath"

                # ASSERT ABSENT, not present: gemini-cli 0.53 hard-errors on
                # general.defaultApprovalMode = "yolo" (invalid enum) and
                # refuses to start, so rendering it would break the tool.
                jq -e '.general.defaultApprovalMode == null' "$geminiSettingsPath"

                jq -e 'has("model") | not' "$geminiSettingsPath"

                # Policy Engine TOML: deny rules from the shared list
                grep -q 'commandPrefix = "gh repo delete"' "$geminiPolicyTomlPath"
                grep -q 'decision = "deny"' "$geminiPolicyTomlPath"
                grep -q 'priority = 200' "$geminiPolicyTomlPath"

                n=${toString (builtins.length fixtureDeny)}
                [ "$(grep -c 'decision = "deny"' "$geminiPolicyTomlPath")" -eq "$n" ]

                touch "$out"
              '';
        }
        // validationChecks
      );
    };
}
