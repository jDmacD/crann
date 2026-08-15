# Shared helper for building an optnix scope entry, used by both the nixos
# and home optnix modules (modules/nixos/optnix.nix, modules/home/optnix.nix)
# so the scope shape (description/evaluator/options-list-file) stays
# identical across classes; only what varies per class (the option tree and,
# for home-manager, the name transform) is passed in.
#
# This is NOT a flake-parts module — the `/_` prefix keeps import-tree from
# auto-importing it (see CLAUDE.md). It's a plain function, imported
# relatively.
{
  lib,
  optnixLib,
  options,
  description,
  evaluator ? "",
  transform ? null,
}:
{
  inherit description evaluator;
  options-list-file = optnixLib.mkOptionsList (
    { inherit options; } // lib.optionalAttrs (transform != null) { inherit transform; }
  );
}
