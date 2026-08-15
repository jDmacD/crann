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
            # programs.claude-code.plugins entries accept. Use .outPath, not
            # the input attrset itself — the attrset only coerces to a path
            # via __toString/JSON serialization, which passed silently under
            # nix eval --json but fails strict `types.path` checking on older
            # nixpkgs pins (no isPath/isString match), throwing deep inside
            # `system.build.toplevel` merge instead of here.
            default = inputs.claude-obsidian.outPath;
            defaultText = lib.literalExpression "inputs.claude-obsidian.outPath";
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
          # List form, not the newer attrsOf form: home-manager.plugins' type
          # changed from listOf to either(attrsOf, listOf) partway through
          # 2026, and crann must stay portable to consumers pinned to either
          # side of that. The only cost of the list form is a cosmetic
          # unstable-store-path-name warning on newer home-manager — the
          # plugin still links and works.
          plugins = lib.mkIf cfg.claude-obsidian.enable [ cfg.claude-obsidian.source ];
        };

        home.packages = lib.mkIf cfg.claude-obsidian.enable [
          cfg.claude-obsidian.python.package
          # The plugin is linked under a hash-named store path that moves on
          # every rev bump, so expose the portable CLI under a stable name
          # instead of making callers rediscover ~/.claude/skills/<hash>-.../
          # scripts/claude-obsidian.py by hand.
          (pkgs.writeShellScriptBin "claude-obsidian" ''
            exec ${cfg.claude-obsidian.python.package}/bin/python3 ${cfg.claude-obsidian.source}/scripts/claude-obsidian.py "$@"
          '')
        ];
      };
    };
}
