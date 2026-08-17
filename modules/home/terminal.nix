# Terminal emulators and the CLI tooling that lives inside them, home-manager
# class. Emulators and utilities are one module because a host effectively
# always wants both; each program has its own sub-`enable` so a consumer can
# take a subset.
#
# Sub-`enable = false` means "crann does not touch this program" rather than
# "force it off": every block is a `mkIf`, so a consumer can still configure
# e.g. kitty itself without colliding with a `programs.kitty.enable = false`
# definition from here.
#
# Theming is deliberately NOT set here. Stylix's autoEnable picks these
# programs up on its own, and the host controls which targets apply via
# `crann.stylix.extraSettings.targets.*` — see modules/hosts/test.nix.
{ ... }:
{
  flake.modules.homeManager.terminal =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.terminal;
    in
    {

      options.crann.terminal = {
        enable = lib.mkEnableOption "terminal";

        packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = with pkgs; [
            libsixel
            yq-go
            jq
            fd
            fzf
            bat
            ripgrep
          ];
          defaultText = lib.literalExpression "[ pkgs.libsixel ]";
          description = "The terminal tools to install. Replaces crann's default set.";
        };

        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          example = lib.literalExpression "[ pkgs.hello ]";
          description = "Extra packages installed alongside `packages`.";
        };

        # --- emulators ---

        ghostty = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to install and configure ghostty.";
          };
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.ghostty;
            defaultText = lib.literalExpression "pkgs.ghostty";
            description = "The ghostty package to use.";
          };
          extraSettings = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
            description = "Extra ghostty settings merged over crann's defaults.";
          };
        };

        foot = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to install and configure foot.";
          };
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.foot;
            defaultText = lib.literalExpression "pkgs.foot";
            description = "The foot package to use.";
          };
          extraSettings = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
            description = "Extra foot settings merged over crann's defaults.";
          };
        };

        kitty = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether to install and configure kitty.";
          };
          extraSettings = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
            description = "Extra kitty settings merged over crann's defaults.";
          };
        };

        # --- utilities ---

        eza.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to install and configure eza.";
        };

        bat.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to install and configure bat.";
        };

        btop.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to install and configure btop.";
        };

        zoxide.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to install and configure zoxide.";
        };

        starship = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to install and configure starship.";
          };
          extraSettings = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
            description = "Extra starship settings merged over crann's defaults.";
          };
        };

        zellij = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to install and configure zellij.";
          };
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.zellij;
            defaultText = lib.literalExpression "pkgs.zellij";
            description = "The zellij package to use.";
          };
          extraSettings = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
            description = "Extra zellij settings merged over crann's defaults.";
          };
        };
      };

      config = lib.mkIf cfg.enable {

        programs.ghostty = lib.mkIf cfg.ghostty.enable {
          enable = true;
          package = cfg.ghostty.package;
          settings = lib.mkMerge [
            {
              shell-integration-features = "ssh-terminfo,ssh-env";
            }
            cfg.ghostty.extraSettings
          ];
        };

        programs.foot = lib.mkIf cfg.foot.enable {
          enable = true;
          package = cfg.foot.package;
          settings = lib.mkMerge [
            {
              main.term = "xterm-256color";
            }
            cfg.foot.extraSettings
          ];
        };

        programs.kitty = lib.mkIf cfg.kitty.enable {
          enable = true;
          settings = lib.mkMerge [
            {
              disable_ligatures = "cursor";
              cursor_shape = "block";
              scrollback_lines = 10000;
              mouse_hide_wait = 0;
              detect_urls = "yes";
              show_hyperlink_targets = "yes";
              url_style = "straight";
              strip_trailing_spaces = "smart";
              focus_follows_mouse = "no";
              enable_audio_bell = "no";
              tab_bar_edge = "bottom";
              tab_bar_style = "powerline";
              tab_powerline_style = "slanted";
              tab_bar_align = "left";
              tab_bar_min_tabs = 2;
              tab_switch_strategy = "previous";
              dynamic_background_opacity = "yes";
              update_check_interval = 0;
              allow_hyperlinks = "yes";
            }
            cfg.kitty.extraSettings
          ];
        };

        programs.eza = lib.mkIf cfg.eza.enable {
          enable = true;
          git = true;
          icons = "auto";
        };

        programs.bat.enable = lib.mkIf cfg.bat.enable true;

        programs.btop.enable = lib.mkIf cfg.btop.enable true;

        programs.zoxide.enable = lib.mkIf cfg.zoxide.enable true;

        programs.starship = lib.mkIf cfg.starship.enable {
          enable = true;
          settings = lib.mkMerge [
            {
              kubernetes.disabled = false;
              localip = {
                ssh_only = false;
                disabled = false;
              };
              status.disabled = false;
            }
            cfg.starship.extraSettings
          ];
        };

        programs.zellij = lib.mkIf cfg.zellij.enable {
          enable = true;
          package = cfg.zellij.package;
          # Deliberate: zellij's zsh integration auto-starts a session on every
          # shell, which is not wanted here.
          enableZshIntegration = false;
          settings = cfg.zellij.extraSettings;
        };

        home.packages = cfg.packages ++ cfg.extraPackages;
      };
    };
}
