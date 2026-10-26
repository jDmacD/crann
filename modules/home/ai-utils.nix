{ inputs, withSystem, ... }:
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

      # Appended to programs.claude-code.context when claude-obsidian is
      # enabled. Stays generic/portable (no vault path, no methodology mode)
      # since those are per-vault choices, not something crann can assume for
      # every consumer; the vault itself is discovered at runtime via
      # .claude-obsidian.json / CLAUDE_OBSIDIAN_VAULT / current-directory
      # discovery, per claude-obsidian's own compound-vault contract.
      claudeObsidianContext = ''
        ## claude-obsidian

        This machine has the claude-obsidian plugin enabled for persistent
        Obsidian-vault memory. When writing to a claude-obsidian vault
        (resolved via `.claude-obsidian.json`, `CLAUDE_OBSIDIAN_VAULT`, or
        workspace config):

        - Never use raw `Write`/`Edit` on a vault's `wiki/`. Always go through
          the plugin's transaction core (`claude-obsidian.transaction.v1`:
          read expected hashes, build a bundle, `transaction inspect` for a
          dry-run, then `transaction apply` with the approved plan hash). A
          raw write silently skips the vault's locking, hash verification,
          and required coupled index/log/hot-cache updates.
        - Never write `.vault-meta/`. The engine owns its locks, journals and
          retrieval indexes, and no bundle may target them. Change the
          methodology mode only with `claude-obsidian mode set`.
        - `inbox/` is the user's source intake. Read it, never modify it, and
          bring a source in with `capture plan`/`capture apply`, which writes
          to `.raw/captured/`.
        - The transaction engine only creates or replaces files. Moving or
          deleting pages (e.g. into a PARA archives folder) is a separate,
          explicitly approved migration, not something to do with `git mv`.

        Prefer invoking the relevant `claude-obsidian:*` skill (save,
        wiki-ingest, wiki-query, wiki-mode, wiki-lint, ...) so its
        instructions load into context before touching vault state, rather
        than replaying the transaction pattern from memory alone.
      '';
    in
    {

      options.crann.ai-utils = {
        enable = lib.mkEnableOption "ai-utils";

        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ pkgs.defuddle ];
          defaultText = lib.literalExpression "[ pkgs.defuddle ]";
          description = "Extra external tools available alongside ai-utils (e.g. defuddle, the optional HTML-to-Markdown cleaner used by claude-obsidian's defuddle skill). Replaces crann's default set.";
        };

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

        mcp.grafana = {
          enable = lib.mkEnableOption "the official Grafana MCP server (grafana/mcp-grafana) for Claude Code";

          package = lib.mkPackageOption pkgs "mcp-grafana" { };

          url = lib.mkOption {
            type = lib.types.str;
            example = "https://grafana.example.com";
            description = "Base URL of the Grafana instance (GRAFANA_URL).";
          };

          tokenFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "/run/user/1000/secrets/grafana_mcp_token";
            description = ''
              Path to a file holding a Grafana service account token, read at
              runtime via GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE so the token never
              enters the Nix store. Secret-manager agnostic: point it at a
              sops-nix/agenix path or any other file.
            '';
          };

          readOnly = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Pass --disable-write so the server only registers read tools.";
          };

          extraArgs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [
              "--disable-oncall"
              "--disable-incident"
            ];
            description = "Extra command-line arguments for mcp-grafana (e.g. --disable-<category> to trim the tool list).";
          };
        };

        channels.grafana = {
          enable = lib.mkEnableOption ''
            the Grafana alerts channel: a launcher that starts Claude Code with
            a channel server receiving Grafana webhook notifications. The
            server is loaded only in sessions started through the launcher
            (via --mcp-config), not in every session, so only one process
            binds the port'';

          package = lib.mkOption {
            type = lib.types.package;
            # crann's own package, via withSystem rather than inputs.self.
            default = withSystem pkgs.stdenv.hostPlatform.system (
              { config, ... }: config.packages.claude-channel-grafana
            );
            defaultText = lib.literalExpression "crann.packages.\${system}.claude-channel-grafana";
            description = "The channel server package.";
          };

          launcherName = lib.mkOption {
            type = lib.types.str;
            default = "claude-alerts";
            description = "Name of the launcher command added to home.packages.";
          };

          host = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            example = "192.168.178.103";
            description = "Address the webhook listener binds to. A non-loopback address requires tokenFile.";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 8788;
            description = "Port the webhook listener binds to.";
          };

          tokenFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "/run/user/1000/secrets/grafana_channel_token";
            description = ''
              Path to a file holding the bearer token Grafana's webhook contact
              point must send (Authorization header, scheme Bearer). Read at
              runtime so it never enters the Nix store. Required unless host
              is a loopback address.
            '';
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
          context = lib.mkIf (cfg.claude-code.context != null || cfg.claude-obsidian.enable) (
            lib.concatStringsSep "\n---\n" (
              lib.optional (cfg.claude-code.context != null) cfg.claude-code.context
              ++ lib.optional cfg.claude-obsidian.enable claudeObsidianContext
            )
          );
          # Attrset form (requires home-manager's newer either(attrsOf, listOf)
          # plugins type). Gives the plugin directory a stable name instead of
          # the list form's hash-derived store path name.
          plugins = lib.mkIf cfg.claude-obsidian.enable {
            claude-obsidian = cfg.claude-obsidian.source;
          };
          mcpServers = lib.mkIf cfg.mcp.grafana.enable {
            grafana = {
              type = "stdio";
              command = lib.getExe cfg.mcp.grafana.package;
              args = lib.optional cfg.mcp.grafana.readOnly "--disable-write" ++ cfg.mcp.grafana.extraArgs;
              env = {
                GRAFANA_URL = cfg.mcp.grafana.url;
              }
              // lib.optionalAttrs (cfg.mcp.grafana.tokenFile != null) {
                GRAFANA_SERVICE_ACCOUNT_TOKEN_FILE = cfg.mcp.grafana.tokenFile;
              };
            };
          };
        };

        home.packages =
          cfg.extraPackages
          ++ lib.optionals cfg.claude-obsidian.enable [
            cfg.claude-obsidian.python.package
            # The plugin is linked under a hash-named store path that moves on
            # every rev bump, so expose the portable CLI under a stable name
            # instead of making callers rediscover ~/.claude/skills/<hash>-.../
            # scripts/claude-obsidian.py by hand.
            (pkgs.writeShellScriptBin "claude-obsidian" ''
              exec ${cfg.claude-obsidian.python.package}/bin/python3 ${cfg.claude-obsidian.source}/scripts/claude-obsidian.py "$@"
            '')
          ]
          ++ lib.optional cfg.channels.grafana.enable (
            let
              ch = cfg.channels.grafana;
              mcpConfig = pkgs.writeText "grafana-alerts-mcp.json" (
                builtins.toJSON {
                  mcpServers.grafana-alerts = {
                    type = "stdio";
                    command = lib.getExe ch.package;
                    env = {
                      CHANNEL_HOST = ch.host;
                      CHANNEL_PORT = toString ch.port;
                    }
                    // lib.optionalAttrs (ch.tokenFile != null) {
                      CHANNEL_TOKEN_FILE = ch.tokenFile;
                    };
                  };
                }
              );
            in
            # Custom channels aren't on the research-preview allowlist, so they
            # need the development flag (interactive sessions only; it shows a
            # confirmation dialog at startup).
            pkgs.writeShellScriptBin ch.launcherName ''
              exec ${lib.getExe cfg.claude-code.package} \
                --mcp-config ${mcpConfig} \
                --dangerously-load-development-channels server:grafana-alerts \
                "$@"
            ''
          );
      };
    };
}
