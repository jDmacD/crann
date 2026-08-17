# Wayland userland tools, home-manager class — the per-user counterpart to
# modules/nixos/desktop.nix.
#
# wl-clipboard is here rather than in the noctalia module on purpose: `wl-copy`
# is a CLI tool for piping command output into the selection, so it should not
# be conditional on running a particular shell. Noctalia's runtime closure
# contains no clipboard tooling at all, so nothing else provides it — and if
# clipboard history is enabled in the shell later, it will expect `cliphist`
# and `wl-clipboard` on PATH, which is what `extraPackages` is for.
{ ... }:
{
  flake.modules.homeManager.desktop =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.desktop;
    in
    {

      options.crann.desktop = {
        enable = lib.mkEnableOption "Wayland userland desktop tools";

        packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [
            pkgs.wl-clipboard
            pkgs.scrcpy
          ];
          defaultText = lib.literalExpression "[ pkgs.wl-clipboard pkgs.scrcpy]";
          description = "The desktop userland tools to install. Replaces crann's default set.";
        };

        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          example = lib.literalExpression "[ pkgs.cliphist pkgs.brightnessctl ]";
          description = "Extra packages installed alongside `packages`.";
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages = cfg.packages ++ cfg.extraPackages;
      };
    };
}
