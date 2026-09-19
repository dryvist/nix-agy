# Flake checks for the settings policy. Pure Nix: the policy predicate
# (lib/settings-policy.nix) fires an `assert` at evaluation time, so a
# violation fails `nix flake check` with the policy message — no shell.
{
  pkgs,
  settingsPolicy,
}:
let
  forbidden = settingsPolicy.forbiddenModelNames;

  # Force the assertion inside assertModelName so tryEval can observe a
  # thrown `assert` rather than returning a lazily-unevaluated attrset.
  checkPolicy = settings: builtins.deepSeq (settingsPolicy.assertModelName forbidden settings) true;

  cleanSettings = { };
  routerRoleSettings = {
    model.name = builtins.elemAt forbidden 0;
  };
in
{
  settings-policy-accepts-clean =
    assert (builtins.tryEval (checkPolicy cleanSettings)).success;
    pkgs.runCommand "settings-policy-accepts-clean" { } "touch $out";

  settings-policy-rejects-router-role =
    assert !(builtins.tryEval (checkPolicy routerRoleSettings)).success;
    pkgs.runCommand "settings-policy-rejects-router-role" { } "touch $out";
}
