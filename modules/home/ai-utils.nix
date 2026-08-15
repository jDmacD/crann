{ inputs, ... }:
{
  flake.modules.homeManager.ai-utils =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.ai-utils;
    in
    {

      options.crann.ai-utils = {
        enable = lib.mkEnableOption "ai-utils";

        claude-code = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to install and configure claude-code.";
          };

          package = lib.mkOption {
            type = lib.types.package;
            # Pull claude-code straight from the llm-agents input rather than via
            # its shared-nixpkgs overlay, so this module is portable to any
            # consumer without touching their nixpkgs.*. The input's own package
            # set already allows unfree, so the consumer doesn't need to.
            default = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
            defaultText = lib.literalExpression "inputs.llm-agents.packages.\${system}.claude-code";
            description = "The claude-code package to use.";
          };

          context = lib.mkOption {
            type = lib.types.nullOr lib.types.lines;
            default = null;
            description = "Extra text passed through to programs.claude-code.context (e.g. machine- or network-specific notes). Unset by default so this module stays portable.";
          };
        };

        claude-obsidian = {
          enable = lib.mkEnableOption "the claude-obsidian plugin and its vault CLI";

          source = lib.mkOption {
            type = with lib.types; either package path;
            # claude-obsidian ships no flake.nix, so it's pulled in as a
            # flake=false input: a plain source tree, which is exactly what
            # programs.claude-code.plugins entries accept.
            default = inputs.claude-obsidian;
            defaultText = lib.literalExpression "inputs.claude-obsidian";
            description = "Source of the claude-obsidian plugin, linked into Claude Code via programs.claude-code.plugins.";
          };

          python.package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.python311;
            defaultText = lib.literalExpression "pkgs.python311";
            description = "Python interpreter used to run claude-obsidian's portable CLI (scripts/claude-obsidian.py).";
          };
        };
      };

      config = lib.mkIf cfg.enable {

        programs.claude-code = {
          enable = cfg.claude-code.enable;
          package = cfg.claude-code.package;
          context = lib.mkIf (cfg.claude-code.context != null) cfg.claude-code.context;
          plugins = lib.mkIf cfg.claude-obsidian.enable [ cfg.claude-obsidian.source ];
        };

        home.packages = lib.mkIf cfg.claude-obsidian.enable [ cfg.claude-obsidian.python.package ];
      };
    };
}
