# yazi, home-manager class. No NixOS-class counterpart: yazi has no system
# service, so this one module already works standalone (worf) and under a
# NixOS-integrated home-manager (surface, picard) alike.
#
# Not wired into stylix here on purpose: crann.stylix runs with autoEnable,
# which turns on every target it knows about (including yazi) regardless of
# whether the program itself is present — see modules/_lib/stylix-settings.nix.
{ ... }:
{
  flake.modules.homeManager.yazi =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.yazi;
    in
    {
      options.crann.yazi = {
        enable = lib.mkEnableOption "yazi";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.yazi;
          defaultText = lib.literalExpression "pkgs.yazi";
          description = "The yazi package to use.";
        };

        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          example = lib.literalExpression "[ pkgs.ffmpegthumbnailer pkgs.poppler_utils pkgs.jq ]";
          description = ''
            Extra packages added to yazi's own wrapper PATH (previewers and
            similar tools yazi shells out to), not the user profile.
          '';
        };

        enableZshIntegration = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether to wrap yazi's shell function (`y` by default) so leaving
            yazi can `cd` the parent shell to yazi's last directory. crann's
            own shells module configures zsh as the default interactive shell.
          '';
        };

        settings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Extra yazi settings (TOML-shaped) merged over crann's defaults.";
        };
      };

      config = lib.mkIf cfg.enable {

        programs.yazi = {
          enable = true;
          package = cfg.package;
          extraPackages = cfg.extraPackages;
          enableZshIntegration = cfg.enableZshIntegration;
          settings = cfg.settings;
        };

      };
    };
}
