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
{% if type == 'homeManager' %}
        packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ pkgs.hello ];
          defaultText = lib.literalExpression "[ pkgs.hello ]";
          description = "The {{ name }} tools to install. Replaces crann's default set.";
        };

        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          example = lib.literalExpression "[ pkgs.hello ]";
          description = "Extra packages installed alongside `packages`.";
        };

        # {{ name }} = {
        #   enable = lib.mkOption {
        #     type = lib.types.bool;
        #     default = true;
        #     description = "Whether to install and configure {{ name }}.";
        #   };

        #   package = lib.mkOption {
        #     type = lib.types.package;
        #     default = pkgs.{{ name }};
        #     defaultText = lib.literalExpression "pkgs.{{ name }}";
        #     description = "The {{ name }} package to use.";
        #   };

        #  extraSettings = lib.mkOption {
        #    type = lib.types.attrsOf lib.types.anything;
        #    default = { };
        #    description = "Extra {{ name }} settings merged over crann's defaults.";
        #  };
        # };
{% elif type == 'nixos' %}
        packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ pkgs.hello ];
          defaultText = lib.literalExpression "[ pkgs.hello ]";
          description = "The {{ name }} tools to install. Replaces crann's default set.";
        };

        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          example = lib.literalExpression "[ pkgs.hello ]";
          description = "Extra packages installed alongside `packages`.";
        };

        # package = lib.mkOption {
        #   type = lib.types.package;
        #   default = pkgs.{{ name }};
        #   defaultText = lib.literalExpression "pkgs.{{ name }}";
        #   description = "The {{ name }} package to use.";
        # };

        # extraSettings = lib.mkOption {
        #   type = lib.types.attrsOf lib.types.anything;
        #   default = { };
        #   description = "Extra {{ name }} settings merged over crann's defaults.";
        # };

        # user = lib.mkOption {
        #   type = lib.types.str;
        #   default = "{{ name }}";
        #   description = "User account under which {{ name }} runs.";
        # };
{% endif %}
      };
      config = lib.mkIf cfg.enable {
{% if type == 'homeManager' %}
        home.packages = cfg.packages ++ cfg.extraPackages;

        # programs.{{ name }} = {
        #   enable = cfg.{{ name }}.enable;
        #   package = cfg.{{ name }}.package;
        #   settings = cfg.{{ name }}.extraSettings;
        # };

{% elif type == 'nixos' %}
        environment.systemPackages = cfg.packages ++ cfg.extraPackages;

        # services.{{ name }} = {
        #   enable = cfg.enable;
        #   package = cfg.package;
        #   settings = cfg.extraSettings;
        # };

{% endif %}
      };
    };
}