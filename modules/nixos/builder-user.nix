{ ... }:
{
  flake.modules.nixos.builderUser =
    {
      config,
      ...
    }:
    let
      cfg = config.crann.builderUser;
    in
    {
      options.crann.builderUser = {

      };

      config = lib.mkIf cfg.enable {

  users.users.builder = {
    isNormalUser = true;
    createHome = false;
    ignoreShellProgramCheck = true;
    group = "builder";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDnim/f3xwmFw/DB9zeHtQSr9i2uKxwsiXkEgE2FdFcY root@picard"
    ];
  };
  users.groups.builder = { };
  nix.settings.trusted-users = [ "builder" ];

      };
    };
}