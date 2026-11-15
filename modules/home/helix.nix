# Helix editor, home-manager class. Ported from blueprint's
# `nix/modules/home/editors.nix`.
#
# The language servers are one overridable `languageServers` list plus an
# additive `extraPackages`, like the kubernetes module's package bag. They go
# into `programs.helix.extraPackages`, so they're on Helix's PATH only, not
# the user's.
{ ... }:
{
  flake.modules.homeManager.helix =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.helix;
    in
    {

      options.crann.helix = {
        enable = lib.mkEnableOption "helix";

        defaultEditor = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to set Helix as `$EDITOR`.";
        };

        languageServers = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = with pkgs; [
            nil
            nixd
            marksman
            ruff
            bash-language-server
            yaml-language-server
            terraform-ls
          ];
          defaultText = lib.literalExpression "[ nil nixd marksman ruff bash-language-server yaml-language-server terraform-ls ]";
          description = "Language servers on Helix's PATH. Replaces crann's default set.";
        };

        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Extra packages on Helix's PATH, alongside `languageServers`.";
        };
      };

      config = lib.mkIf cfg.enable {
        programs.helix = {
          enable = true;
          defaultEditor = cfg.defaultEditor;
          extraPackages = cfg.languageServers ++ cfg.extraPackages;
          languages.language = [
            {
              name = "nix";
              auto-format = true;
              formatter.command = lib.getExe pkgs.nixfmt;
            }
          ];
        };
      };
    };
}
