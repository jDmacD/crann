{ inputs, ... }:
{
  # Declares the `flake.modules.<class>.<name>` output schema (homeManager /
  # nixos / darwin) that every feature module writes to. Without this,
  # flake-parts has no option for `flake.modules` and evaluation fails with
  # "option `flake.modules' is defined multiple times".
  imports = [ inputs.flake-parts.flakeModules.modules ];

  config = {
    systems = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
}
