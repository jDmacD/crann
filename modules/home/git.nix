# Git and its surrounding tooling (gh, lazygit, pre-commit), home-manager class.
#
# Identity is deliberately not defaulted: it varies per profile (personal vs
# work vs machine), so `userName`/`userEmail` are nullable and simply omitted
# when unset. A consumer can either set them here or keep defining
# `programs.git.settings.user.*` in its own profile module — both merge.
{ ... }:
{
  flake.modules.homeManager.git =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.git;
    in
    {

      options.crann.git = {
        enable = lib.mkEnableOption "git";

        userName = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "jDmacD";
          description = "Value for git's `user.name`, or null to leave it unset.";
        };

        userEmail = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "someone@example.com";
          description = "Value for git's `user.email`, or null to leave it unset.";
        };

        defaultBranch = lib.mkOption {
          type = lib.types.str;
          default = "main";
          description = "Branch name used by `git init`.";
        };

        extraSettings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Extra git settings merged over crann's defaults.";
        };

        gh = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to install and configure the GitHub CLI.";
          };
          extraSettings = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
            description = "Extra gh settings merged over crann's defaults.";
          };
        };

        lazygit.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to install and configure lazygit.";
        };

        pre-commit.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to install the pre-commit framework.";
        };

        commitizen.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to install commitizen";
        };
      };

      config = lib.mkIf cfg.enable {

        programs.git = {
          enable = true;
          settings = lib.mkMerge [
            {
              init.defaultBranch = cfg.defaultBranch;
            }
            (lib.mkIf (cfg.userName != null) { user.name = cfg.userName; })
            (lib.mkIf (cfg.userEmail != null) { user.email = cfg.userEmail; })
            cfg.extraSettings
          ];
        };

        programs.gh = lib.mkIf cfg.gh.enable {
          enable = true;
          settings = lib.mkMerge [
            {
              git_protocol = "ssh";
            }
            cfg.gh.extraSettings
          ];
        };

        programs.lazygit.enable = lib.mkIf cfg.lazygit.enable true;

        home.packages = lib.mkMerge [
          (lib.mkIf cfg.pre-commit.enable [ pkgs.pre-commit ])
          (lib.mkIf cfg.commitizen.enable [ pkgs.commitizen ])
        ];

      };
    };
}
