{ ... }:
{
  flake.modules.nixos.builder-user =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.crann.builder-user;
    in
    {
      options.crann.builder-user = {
        enable = lib.mkEnableOption "a dedicated trusted user for accepting remote Nix builds";

        authorizedKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "SSH public keys allowed to log in as the builder user.";
        };
      };

      config = lib.mkIf cfg.enable {

        users.users.builder = {
          isNormalUser = true;
          createHome = false;
          ignoreShellProgramCheck = true;
          group = "builder";
          openssh.authorizedKeys.keys = cfg.authorizedKeys;
        };
        users.groups.builder = { };
        nix.settings.trusted-users = [ "builder" ];

      };
    };
}
