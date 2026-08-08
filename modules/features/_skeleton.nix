# Template for a reusable crann feature module.
#
# The leading `_` keeps import-tree from auto-loading this file, so it is a
# copy-me reference, not a live module. To create a real module: copy to
# `modules/features/<name>.nix`, drop the underscore, and replace `myfeature`.
#
# Shown as a home-manager module; for a system module swap `homeManager` for
# `nixos` or `darwin` and adjust the config accordingly. See CLAUDE.md for the
# conventions and portability rules this follows.
{ inputs, ... }:
{
  flake.modules.homeManager.myfeature =
    # `inputs` is captured by closure from the flake-parts args above — do NOT
    # add it to this inner argument list.
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.myfeature;
    in
    {
      # Pull in the upstream module this feature wraps, if any.
      # imports = [ inputs.someflake.homeModules.default ];

      # All options live under `crann.<feature>` to avoid collisions.
      options.crann.myfeature = {

        enable = lib.mkEnableOption "myfeature";

        # Typed package, overridable per-host. Default is pulled straight from
        # a flake input (never via `nixpkgs.overlays`) so the module is portable
        # to consumers using `useGlobalPkgs`.
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.hello;
          # default = inputs.someflake.packages.${pkgs.stdenv.hostPlatform.system}.default;
          defaultText = lib.literalExpression "pkgs.hello";
          description = "The myfeature package to use.";
        };

        # A plain scalar option.
        theme = lib.mkOption {
          type = lib.types.str;
          default = "dark";
          description = "Color theme to apply.";
        };

        # An enumerated choice.
        mode = lib.mkOption {
          type = lib.types.enum [
            "auto"
            "manual"
          ];
          default = "auto";
          description = "How myfeature decides what to do.";
        };

        # A nullable option (unset by default).
        extraArgs = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.str);
          default = null;
          description = "Extra CLI args, or null to pass none.";
        };

        # Free-form settings, and a per-host escape hatch merged in below.
        extraSettings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Extra settings merged over the defaults.";
        };
      };

      # Everything under `config` only takes effect when enabled.
      config = lib.mkIf cfg.enable {

        home.packages = [ cfg.package ];

        # Example of merging module defaults with the host's extraSettings.
        # programs.myfeature.settings = lib.mkMerge [
        #   {
        #     theme = cfg.theme;
        #     mode = cfg.mode;
        #   }
        #   (lib.mkIf (cfg.extraArgs != null) { args = cfg.extraArgs; })
        #   cfg.extraSettings
        # ];
      };
    };
}
