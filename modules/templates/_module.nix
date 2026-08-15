{ inputs, ... }:
{
  flake.modules.{{ type }}.{{ name }} =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.{{ name }};
    in
    {
      options.crann.{{ name }} = {
        enable = lib.mkEnableOption "{{ name }}";
      };
      config = lib.mkIf cfg.enable { };
    };
}