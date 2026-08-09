{ inputs, ... }:
{
  flake.modules.homeManager.vscode =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.vscode;
    in
    {

      options.crann.vscode = {
        enable = lib.mkEnableOption "vscode";
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.vscode;
          # default = inputs.someflake.packages.${pkgs.stdenv.hostPlatform.system}.default;
          defaultText = lib.literalExpression "pkgs.vscode";
          description = "The vscode package to use.";
        };
        extraUserSettings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Extra vscode settings merged over crann's defaults.";
        };
        extraExtensions = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Extra vscode extensions merged over crann's defaults.";
        };
      };
      config = lib.mkIf cfg.enable {

        programs.vscode = {
          enable = true;
          package = cfg.package;
          profiles = {
            default = {
              userSettings = lib.mkMerge [
                {
                  terminal.integrated.fontFamily = "Symbols Nerd Font Mono";
                  workbench.colorTheme = "Stylix";
                  git.autofetch = true;
                  git.confirmSync = false;
                  sqltools.useNodeRuntime = false;
                  gitlab.keybindingHints.enabled = false;
                  gitlab.duoChat.enabled = false;
                  gitlab.duoCodeSuggestions.enabled = false;
                  gitlab.duoAgentPlatform.enabled = false;
                  gitlab.duo.enabledWithoutGitlabProject = false;
                  gitlab.duoCodeSuggestions.openTabsContext = false;
                  chat.agent.enabled = false;
                  chat.disableAIFeatures = true;
                  chat.showAgentSessionsViewDescription = false;
                  terminal.integrated.initialHint = false;
                  # sops.defaults.ageKeyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
                  cSpell.language = "en-GB";
                  cSpell.enabledFileTypes = {
                    "*" = false;
                  };
                  # markdown-preview-enhanced.pandocPath = "${pkgs.pandoc}/bin/pandoc";
                  # markdown-preview-enhanced.latexEngine = "${pkgs.texliveFull}/bin/xelatex";
                  # markdown-preview-enhanced.imageMagickPath = "${pkgs.imagemagick}/bin/magick";
                  # markdown-preview-enhanced.chromePath = "${pkgs.ungoogled-chromium}/bin/chromium";
                  # markdown-preview-enhanced.usePandocParser = true;
                  # markdown-preview-enhanced.krokiServer = "https://kroki.heanet.io";
                }
                cfg.extraUserSettings
              ];
              extensions = lib.mkMerge [
                (with pkgs.vscode-extensions; [
                  ms-vscode-remote.remote-ssh
                  charliermarsh.ruff
                  ms-python.python
                  bbenoist.nix
                  jnoortheen.nix-ide
                  ms-azuretools.vscode-docker
                  mechatroner.rainbow-csv
                  signageos.signageos-vscode-sops
                  streetsidesoftware.code-spell-checker
                  # shd101wyy.markdown-preview-enhanced
                  anthropic.claude-code
                  gitlab.gitlab-workflow
                  hashicorp.terraform
                  ms-vscode-remote.remote-containers
                ])
                cfg.extraExtensions
              ];
            };
          };
          mutableExtensionsDir = false;
        };

      };
    };
}
