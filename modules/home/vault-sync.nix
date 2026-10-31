# vault-sync, home-manager class: keeps a claude-obsidian vault in sync across
# hosts via its git remote, so Claude Code on each host shares one vault. Needs
# crann.ai-utils with claude-obsidian enabled: it runs claude-obsidian's
# retrieval scripts from crann.ai-utils.claude-obsidian. Ported from blueprint.
#
# Each sync is fetch + rebase --autostash onto origin + push, run:
#   - every `interval` by a systemd user timer (keeps long-lived sessions and
#     the Obsidian app's view fresh, and clones the vault if it's missing)
#   - on Claude SessionStart
#   - on Claude Stop, but only when local commits are unpushed (cheap local
#     check, so it costs nothing on turns that didn't checkpoint the vault)
# A sync is skipped while .vault-meta/mutation.lock exists (a transaction is
# mid-apply). A transaction that read its expected hashes before a pull fails
# its hash check instead of clobbering, so it just needs re-reading.
# On a rebase conflict the rebase is aborted, the local branch is left
# untouched, and the conflict is reported (into Claude's context on
# SessionStart) to be resolved by hand.
# On hosts where a claude-obsidian retrieval index has been built
# (.vault-meta/bm25 exists, via the wiki-retrieve skill), each sync also
# rebuilds it, local-only (--no-llm), whenever the committed wiki/ tree has
# changed. The index is gitignored, so each host keeps its own copy.
#
# Before fetching, a sync also sweeps: wiki/ changes left without a checkpoint
# are committed, once wiki/ has been quiet for `sweepAfter` minutes and every
# transaction journal is complete or rolled back. With several Claude sessions
# saving to one vault, a save that isn't checkpointed before another save
# rewrites index/log/hot can never be checkpointed (TRANSACTION_DRIFT), and its
# leftovers then block or entangle every later session's checkpoint. The sweep
# keeps that from accumulating; the quiet period leaves each session time to
# checkpoint its own operation first.
#
# A UserPromptSubmit hook also injects the vault's hot cache and the pages
# wiki-retrieve ranks highest on each session's first prompt (`recall`).
# Raw-write blocking lives in crann.ai-utils (claude-obsidian.blockRawVaultWrites).
{ ... }:
{
  flake.modules.homeManager.vault-sync =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.vault-sync;
      obsidian = config.crann.ai-utils.claude-obsidian;

      # claude-obsidian's checkpoint ignores global git config
      # (GIT_CONFIG_GLOBAL=/dev/null), so the commit identity has to live in the
      # vault repo's own config.
      gitUser = config.programs.git.settings.user or { };
      setIdentity = lib.optionalString (gitUser ? name && gitUser ? email) ''
        git -C "$vault" config user.name ${lib.escapeShellArg gitUser.name}
        git -C "$vault" config user.email ${lib.escapeShellArg gitUser.email}
      '';

      # wiki-retrieve's reranker accepts these hosts without
      # --allow-remote-ollama (validate_ollama_config in claude-obsidian's
      # scripts/contextual-prefix.py), so a URL pointing at one gets neither the
      # flag nor the approval wording.
      rerankIsLocal =
        cfg.rerankOllamaUrl != null
        &&
          builtins.match "https?://(localhost|127\\.0\\.0\\.1|\\[::1])(:[0-9]+)?/?" cfg.rerankOllamaUrl
          != null;
      allowRemoteFlag = lib.optionalString (!rerankIsLocal) " --allow-remote-ollama";
      rerankIntro = lib.removeSuffix "\n" (
        if rerankIsLocal then
          ''
            wiki-retrieve reranks against this host's own Ollama at
            `${cfg.rerankOllamaUrl}`, so the query and candidate chunk text never
            leave the machine and no `--allow-remote-ollama` is needed. Use only
            the `${cfg.rerankModel}` model, never the Ollama's `:cloud` models.
            Invoke it as:
          ''
        else
          ''
            ${cfg.rerankApproval} for wiki-retrieve to
            rerank against the Ollama at `${cfg.rerankOllamaUrl}`, sending the
            query and candidate chunk text. This approval covers only that URL and
            only the `${cfg.rerankModel}` model, never the Ollama's `:cloud`
            models. Invoke it as:
          ''
      );

      vault-sync = pkgs.writeShellApplication {
        name = "vault-sync";
        runtimeInputs = with pkgs; [
          coreutils
          findutils
          git
          jq
          openssh
          util-linux
        ];
        text = ''
          vault=${lib.escapeShellArg cfg.path}
          remote=${lib.escapeShellArg cfg.remote}
          if_ahead=false
          [ "''${1:-}" = "--if-ahead" ] && if_ahead=true

          state="''${XDG_RUNTIME_DIR:-/tmp}/vault-sync"
          mkdir -p "$state"
          exec 9>"$state/lock"
          flock -w 30 9 || exit 0

          if [ ! -d "$vault/.git" ]; then
            if [ -e "$vault" ]; then
              echo "vault-sync: $vault exists but is not a git repo; not syncing" >&2
              exit 1
            fi
            mkdir -p "$(dirname "$vault")"
            timeout 60 git clone --quiet "$remote" "$vault"
            ${setIdentity}
            echo "vault-sync: cloned $remote into $vault"
            exit 0
          fi

          cd "$vault"
          ${setIdentity}
          upstream_ahead() { git rev-list --count '@{u}..HEAD'; }

          refresh_index() {
            [ -d .vault-meta/bm25 ] || return 0
            local tree
            tree=$(git rev-parse HEAD:wiki)
            [ "$tree" = "$(cat "$state/indexed-tree" 2>/dev/null)" ] && return 0
            if ${obsidian.python.package}/bin/python3 ${obsidian.source}/scripts/contextual-prefix.py --vault "$vault" --all --no-llm >"$state/index.log" 2>&1 \
              && ${obsidian.python.package}/bin/python3 ${obsidian.source}/scripts/bm25-index.py --vault "$vault" build >>"$state/index.log" 2>&1; then
              printf '%s\n' "$tree" >"$state/indexed-tree"
              echo "vault-sync: rebuilt the retrieval index"
            else
              echo "vault-sync: retrieval index rebuild failed; wiki-retrieve will fall back to text search" >&2
              tail -n 5 "$state/index.log" >&2
            fi
          }

          ${lib.optionalString (cfg.sweepAfter != null) ''
            sweep() {
              [ -n "$(git status --porcelain -- wiki)" ] || return 0
              # Fresh changes belong to a session that may be about to checkpoint.
              [ -z "$(find wiki -mmin -${toString cfg.sweepAfter} -print -quit)" ] || return 0
              local open
              open=$(find .vault-meta/transactions -mindepth 2 -maxdepth 2 -name journal.json \
                -exec jq -r 'select(.state != "complete" and .state != "rolled-back") | input_filename' {} + 2>/dev/null \
                | head -n1)
              if [ -n "$open" ]; then
                echo "vault-sync: not sweeping, transaction $(basename "$(dirname "$open")") isn't complete" >&2
                return 0
              fi
              local since ops
              since=$(git log -1 --format=%ct)
              ops=$(find .vault-meta/transactions -mindepth 1 -maxdepth 1 -type d -newermt "@$since" \
                ! -exec test -e '{}/checkpoint.json' ';' -printf '- %f\n' | sort)
              git add -A -- wiki
              git commit --quiet -m "wiki: sweep changes left without a checkpoint" \
                -m "Operations completed since the last commit without a checkpoint:" \
                -m "''${ops:-(none found)}" -- wiki
              echo "vault-sync: committed wiki/ changes left without a checkpoint"
            }
          ''}

          if $if_ahead && [ "$(upstream_ahead)" -eq 0 ]; then
            exit 0
          fi
          if [ -e .vault-meta/mutation.lock ]; then
            echo "vault-sync: skipped, a vault transaction is in progress"
            exit 0
          fi
          gitdir=$(git rev-parse --git-dir)
          if [ -d "$gitdir/rebase-merge" ] || [ -d "$gitdir/rebase-apply" ] || [ -f "$gitdir/MERGE_HEAD" ]; then
            echo "vault-sync: a rebase/merge is in progress in $vault; resolve it by hand" >&2
            exit 1
          fi
          ${lib.optionalString (cfg.sweepAfter != null) "sweep"}

          if ! timeout 30 git fetch --quiet origin; then
            echo "vault-sync: fetch failed (offline?); vault not synced"
            refresh_index
            exit 0
          fi

          behind=$(git rev-list --count 'HEAD..@{u}')
          if [ "$behind" -gt 0 ]; then
            if ! out=$(git rebase --autostash '@{u}' 2>&1); then
              git rebase --abort >/dev/null 2>&1 || true
              echo "vault-sync: CONFLICT rebasing $vault onto origin; local branch left unchanged, resolve by hand:" >&2
              printf '%s\n' "$out" | tail -n 15 >&2
              exit 1
            fi
            case "$out" in
              *"autostash resulted in conflicts"*)
                echo "vault-sync: pulled $behind commit(s), but uncommitted local edits conflicted and are kept in 'git stash'"
                ;;
              *)
                echo "vault-sync: pulled $behind commit(s) from origin"
                ;;
            esac
          fi

          ahead=$(upstream_ahead)
          if [ "$ahead" -gt 0 ]; then
            if timeout 30 git push --quiet origin HEAD; then
              echo "vault-sync: pushed $ahead commit(s) to origin"
            else
              echo "vault-sync: push failed; $ahead commit(s) still unpushed" >&2
            fi
          fi

          refresh_index
        '';
      };

      # UserPromptSubmit hook: on a session's first real prompt, injects the
      # vault's hot cache and the pages wiki-retrieve ranks highest for that
      # prompt, so Claude checks the vault without being asked. Reranks against
      # rerankOllamaUrl when set; a slow or failed rerank (cold model load) falls
      # back to plain BM25 so the prompt isn't held up.
      vault-recall = pkgs.writeShellApplication {
        name = "vault-recall";
        runtimeInputs = with pkgs; [
          coreutils
          findutils
          gawk
          jq
        ];
        text = ''
          vault=${lib.escapeShellArg cfg.path}
          input="$(cat)"
          session="$(printf '%s' "$input" | jq -r '.session_id // empty')"
          prompt="$(printf '%s' "$input" | jq -r '.prompt // empty')"

          [ -n "$session" ] && [ -f "$vault/wiki/hot.md" ] || exit 0
          # Slash commands make poor queries; wait for the first real prompt.
          case "$prompt" in "" | /*) exit 0 ;; esac

          state="''${XDG_RUNTIME_DIR:-/tmp}/vault-sync/recall"
          mkdir -p "$state"
          find "$state" -type f -mtime +7 -delete 2>/dev/null || true
          marker="$state/$session"
          [ -e "$marker" ] && exit 0
          : >"$marker"

          query="$(printf '%s' "$prompt" | head -c 2000)"
          retrieve=(${obsidian.python.package}/bin/python3 ${obsidian.source}/scripts/retrieve.py
            --vault "$vault" "$query" --top ${toString cfg.recall.top})
          results=""
          ${lib.optionalString (cfg.rerankOllamaUrl != null) ''
            results="$(OLLAMA_URL=${lib.escapeShellArg cfg.rerankOllamaUrl} timeout ${toString cfg.recall.rerankTimeout} \
              "''${retrieve[@]}"${allowRemoteFlag} --model ${lib.escapeShellArg cfg.rerankModel} 2>/dev/null)" || results=""
          ''}
          [ -n "$results" ] || results="$("''${retrieve[@]}" --no-rerank 2>/dev/null)" || results=""

          hot="$(awk 'NR == 1 && /^---$/ { fm = 1; next } fm && /^---$/ { fm = 0; next } !fm' "$vault/wiki/hot.md")"
          matches="$(printf '%s' "$results" | jq -r '
            .strategy as $s
            | if (.candidates | length) == 0 then "No matching pages."
              else "Ranked by `\($s)`:\n" + ([.candidates[]
                | "- `\(.absolute_path)`: \(.snippet | gsub("\\s+"; " ") | .[0:200])"] | join("\n"))
              end' 2>/dev/null)" \
            || matches="Retrieval unavailable (index missing or stale); use claude-obsidian:wiki-query if the vault is relevant."

          context="## Vault recall (auto-injected on this session's first prompt)

          The claude-obsidian vault at \`$vault\` is ${cfg.recall.vaultDescription}. Below are its hot cache and the pages that best match this prompt. Search hits are pointers, not evidence: Read the relevant pages before answering. Ignore them if the prompt has nothing to do with the vault.

          ### Hot cache (wiki/hot.md)

          $hot

          ### Matching pages

          $matches"
          jq -n --arg ctx "$context" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
        '';
      };

      # Hooks ship as a managed plugin rather than programs.claude-code.settings,
      # so ~/.claude/settings.json stays a mutable file.
      plugin = pkgs.runCommand "vault-sync-claude-plugin" { } ''
        mkdir -p $out/.claude-plugin $out/hooks
        cp ${
          pkgs.writers.writeJSON "plugin.json" {
            name = "vault-sync";
            version = "1.1.0";
            description = "Syncs the claude-obsidian vault via git and recalls it on a session's first prompt";
          }
        } $out/.claude-plugin/plugin.json
        cp ${
          pkgs.writers.writeJSON "hooks.json" {
            hooks = {
              SessionStart = [
                {
                  matcher = "startup|resume|clear";
                  hooks = [
                    {
                      type = "command";
                      command = lib.getExe vault-sync;
                      timeout = 90;
                    }
                  ];
                }
              ];
              Stop = [
                {
                  hooks = [
                    {
                      type = "command";
                      command = "${lib.getExe vault-sync} --if-ahead";
                      timeout = 90;
                    }
                  ];
                }
              ];
              UserPromptSubmit = lib.optionals cfg.recall.enable [
                {
                  hooks = [
                    {
                      type = "command";
                      command = lib.getExe vault-recall;
                      timeout = cfg.recall.rerankTimeout + 15;
                    }
                  ];
                }
              ];
            };
          }
        } $out/hooks/hooks.json
      '';
    in
    {
      options.crann.vault-sync = {
        enable = lib.mkEnableOption "git sync of the claude-obsidian vault";

        path = lib.mkOption {
          type = lib.types.str;
          default = "${config.home.homeDirectory}/obsidian/technodrome";
          description = "Local checkout of the vault. Cloned from `remote` if missing.";
        };

        remote = lib.mkOption {
          type = lib.types.str;
          example = "ssh://git@codeberg.org/someone/vault.git";
          description = "Git remote the vault syncs with.";
        };

        rerankOllamaUrl = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "https://ollama.local.jtec.xyz";
          description = ''
            Ollama endpoint that wiki-retrieve reranks against, in the recall
            hook and in the Claude Code context. For any host other than
            `localhost`, `127.0.0.1` or `[::1]`, setting it records the user's
            standing approval (worded by `rerankApproval`) to send queries and
            candidate chunk text there with `--allow-remote-ollama`, using only
            `rerankModel`. A loopback URL needs no approval or flag, and the
            context describes it as the host's own Ollama.
          '';
        };

        rerankApproval = lib.mkOption {
          type = lib.types.str;
          default = "The user has given standing approval";
          example = "jDmacD has given standing approval (2026-10-11)";
          description = "Opening of the Claude Code context sentence that records the rerank approval. Unused when `rerankOllamaUrl` is loopback.";
        };

        rerankModel = lib.mkOption {
          type = lib.types.str;
          default = "nomic-embed-text-v2-moe";
          description = "Embedding model wiki-retrieve reranks with on `rerankOllamaUrl`.";
        };

        recall = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Inject the vault's hot cache and the best-matching pages into
              Claude's context on each session's first prompt.
            '';
          };

          vaultDescription = lib.mkOption {
            type = lib.types.str;
            default = "the user's knowledge vault";
            example = "jDmacD's second brain and project tracker";
            description = "How the recall block describes the vault to Claude.";
          };

          top = lib.mkOption {
            type = lib.types.ints.between 1 20;
            default = 5;
            description = "How many matching pages to list.";
          };

          rerankTimeout = lib.mkOption {
            type = lib.types.ints.positive;
            default = 8;
            description = "Seconds to wait for the rerank before falling back to BM25 order.";
          };
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "5min";
          description = "How often the systemd timer syncs the vault.";
        };

        sweepAfter = lib.mkOption {
          type = lib.types.nullOr lib.types.ints.positive;
          default = 10;
          description = ''
            Minutes wiki/ must be unchanged before a sync commits changes left
            without a checkpoint. Swept commits skip the checkpoint's lint and
            provenance checks. `null` disables the sweep.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = (config.crann.ai-utils.enable or false) && obsidian.enable;
            message = "crann.vault-sync needs crann.ai-utils with claude-obsidian enabled (import inputs.crann.modules.homeManager.ai-utils).";
          }
        ];

        home.packages = [ vault-sync ];

        programs.claude-code.plugins.vault-sync = plugin;

        programs.claude-code.context = lib.mkAfter (
          ''
            ---
            ## Obsidian vault sync

            The claude-obsidian vault lives at `${cfg.path}` on every host that
            enables vault-sync, and is kept in sync through its git remote (`${cfg.remote}`) by
            `vault-sync` (fetch, `rebase --autostash` onto origin, push). It runs from
            a systemd user timer every ${cfg.interval}, on SessionStart, and after
            each turn that leaves unpushed vault commits. It skips while
            `.vault-meta/mutation.lock` exists.

            - Checkpoint (`claude-obsidian checkpoint <operation-id>`) completed
              vault transactions so they get pushed; uncommitted vault changes
              stay local to this host. This is the user's standing request for
              Git history, which claude-obsidian otherwise only makes on request.
              Run it in the same Bash call as the apply
              (`... workflow apply ... && python3 "$CORE" checkpoint <operation-id> --vault ...`):
              other Claude sessions save to this vault too, and once another save
              rewrites index/log/hot, this operation can't be checkpointed
              (`TRANSACTION_DRIFT`).
          ''
          + lib.optionalString (cfg.sweepAfter != null) ''
            - If the checkpoint is refused (lint findings in other sessions' pages,
              `TRANSACTION_DRIFT`, staged changes that aren't yours), don't edit
              other sessions' pages or commit by hand: vault-sync commits
              changes left without a checkpoint once `wiki/` has been quiet for
              ${toString cfg.sweepAfter} minutes. A checkpoint that reports
              `NOTHING_TO_COMMIT` was already swept. Tell the user which it was.
          ''
          + ''
            - `.vault-meta/` is gitignored and per-host, except `mode.json`
              (the methodology mode), which is tracked so every host files new
              notes the same way.
            - If a transaction apply fails its expected-hash check, a sync probably
              pulled newer content: re-read the hashes and rebuild the bundle, don't
              force it.
            - Run `vault-sync` by hand before a large ingest or save to start from
              the latest vault.
            - If vault-sync reports a CONFLICT (usually in the vault's log/index/hot
              cache files), tell the user. Resolve it with a manual rebase in
              `${cfg.path}`, keeping both sides' entries. Don't discard either side
              or force-push.
          ''
          + lib.optionalString cfg.recall.enable ''
            - A UserPromptSubmit hook injects a "Vault recall" block on each
              session's first prompt: the hot cache plus the pages wiki-retrieve
              ranks highest for that prompt. Read the relevant ones before
              answering. A later prompt that turns to vault topics still needs
              its own wiki-query or wiki-retrieve.
          ''
          + lib.optionalString (cfg.rerankOllamaUrl != null) ''

            ### Retrieval reranking

            ${rerankIntro}

            ```bash
            OLLAMA_URL=${cfg.rerankOllamaUrl} python3 "$RETRIEVE" --vault "$VAULT" "$QUERY" --top 5${allowRemoteFlag} --model ${cfg.rerankModel}
            ```

            A cold model load can make the first call fail (a 504 if a gateway
            sits in front). The strategy then reads `bm25+rerank:noop-embed-error`
            and results are in plain BM25 order, so retry once. `bm25+rerank:noop-local-proof` means
            the server didn't prove cloud is disabled (`/api/status` must report
            `cloud.disabled: true`; set `OLLAMA_NO_CLOUD=1` on the server). Retrying
            won't help, so tell the user.
          ''
        );

        systemd.user.services.vault-sync = {
          Unit.Description = "Sync the claude-obsidian vault with its git remote";
          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe vault-sync;
          };
        };

        systemd.user.timers.vault-sync = {
          Unit.Description = "Periodically sync the claude-obsidian vault";
          Timer = {
            OnBootSec = "1min";
            OnUnitActiveSec = cfg.interval;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
    };
}
