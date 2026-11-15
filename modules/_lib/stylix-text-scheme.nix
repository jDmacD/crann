# Gives terminals, editors and CLI tools their own base16 scheme, separate from
# the desktop's `stylix.base16Scheme`. Plain helper (not a flake-parts module):
# a function returning home-manager config, used by both stylix modules —
# directly by modules/home/stylix.nix, and through home-manager.sharedModules by
# modules/nixos/stylix.nix (home-manager users don't see `crann.stylix`).
#
# Stylix targets built on its mkTarget framework take
# `stylix.targets.<name>.colors.override`, recursively merged over the global
# palette. Passing a whole mkSchemeAttrs result replaces every derived form too
# (`withHashtag`, rgb, …), not just base00–base0F.
{
  config,
  lib,
  options,
  scheme,
}:
let
  textTargets = [
    # terminals
    "alacritty"
    "foot"
    "ghostty"
    "kitty"
    "rio"
    "wezterm"
    # editors
    "emacs"
    "helix"
    "neovim"
    "nixvim"
    "vim"
    "vscode"
    "vscodium"
    "zed"
    # CLI and TUI tools
    "bat"
    "bottom"
    "broot"
    "btop"
    "fish"
    "fzf"
    "gdu"
    "gitui"
    "k9s"
    "kubecolor"
    "lazygit"
    "nushell"
    "opencode"
    "starship"
    "tmux"
    "vivid"
    "yazi"
    "zellij"
  ];
  # Only targets this stylix version declares with a `colors` override.
  supported = t: options.stylix.targets ? ${t} && options.stylix.targets.${t} ? colors;
in
lib.mkIf (scheme != null) {
  stylix.targets = lib.genAttrs (lib.filter supported textTargets) (_: {
    colors.override = config.stylix.base16.mkSchemeAttrs scheme;
  });
}
