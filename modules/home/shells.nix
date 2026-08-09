# Interactive shells (zsh + bash), home-manager class.
#
# The alias set is shared between both shells and is gated on whether the
# backing program is actually enabled elsewhere in the configuration, so this
# module stands alone: import it without `terminal` and you simply get fewer
# aliases rather than an alias pointing at a missing binary.
{ ... }:
{
  flake.modules.homeManager.shells =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.shells;

      # Gated on the *consumer's* resolved config, not on crann options — this
      # works whether eza/zoxide/bat come from crann's terminal module or from
      # the host's own configuration.
      aliases =
        lib.optionalAttrs config.programs.eza.enable { ls = "eza"; }
        // lib.optionalAttrs config.programs.zoxide.enable { cd = "z"; }
        // lib.optionalAttrs config.programs.bat.enable { cat = "bat --paging=never"; }
        // lib.optionalAttrs (cfg.flakeInspectPath != null) {
          flake-inspect = "${pkgs.nix-inspect}/bin/nix-inspect --expr 'builtins.getFlake \"${cfg.flakeInspectPath}\"'";
        }
        // cfg.extraAliases;
    in
    {

      options.crann.shells = {
        enable = lib.mkEnableOption "shells";

        zsh.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to configure zsh.";
        };

        bash.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to configure bash.";
        };

        historySize = lib.mkOption {
          type = lib.types.int;
          default = 10000;
          description = "Number of history entries to keep.";
        };

        flakeInspectPath = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "/home/alice/blueprint";
          description = ''
            Path to a flake to expose as a `flake-inspect` alias via nix-inspect.
            Null adds no alias.
          '';
        };

        extraAliases = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Extra shell aliases merged over crann's defaults.";
        };
      };

      config = lib.mkIf cfg.enable {

        programs.zsh = lib.mkIf cfg.zsh.enable {
          enable = true;
          # Disabled to avoid nix-zsh-completions conflicting with
          # nixos-rebuild-ng; compinit is run by hand in initContent instead.
          enableCompletion = false;
          autosuggestion.enable = true;
          syntaxHighlighting.enable = true;
          history.size = cfg.historySize;
          shellAliases = aliases;
          initContent = ''
            # Manually enable completions without nix-zsh-completions
            autoload -U compinit && compinit
          '';
        };

        programs.bash = lib.mkIf cfg.bash.enable {
          enable = true;
          historySize = cfg.historySize;
          shellAliases = aliases;
        };
      };
    };
}
