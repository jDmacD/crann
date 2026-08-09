# Shared stylix theming, imported by both the nixos and home stylix modules
# (modules/nixos/stylix.nix, modules/home/stylix.nix) so the two classes carry
# identical defaults. Lives under _lib so import-tree does not treat it as a
# flake-parts module — it is a plain helper: a function of `pkgs` returning a
# stylix settings attrset.
#
# All packages referenced here (base16-schemes, dejavu_fonts,
# noto-fonts-color-emoji, bibata-cursors) are stock nixpkgs, so this stays
# portable to any consumer without touching their nixpkgs.*. The caller wraps
# this whole attrset in lib.mkDefault, so a host's crann.stylix.extraSettings
# overrides any leaf cleanly.
{ pkgs }:
{
  autoEnable = true;
  base16Scheme = "${pkgs.base16-schemes}/share/themes/material-vivid.yaml";
  polarity = "dark";
  fonts = {
    serif = {
      package = pkgs.dejavu_fonts;
      name = "DejaVu Serif";
    };
    sansSerif = {
      package = pkgs.dejavu_fonts;
      name = "DejaVu Sans";
    };
    monospace = {
      package = pkgs.dejavu_fonts;
      name = "DejaVu Sans Mono";
    };
    emoji = {
      package = pkgs.noto-fonts-color-emoji;
      name = "Noto Color Emoji";
    };
  };
  opacity = {
    terminal = 0.7;
  };
  cursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };
}
