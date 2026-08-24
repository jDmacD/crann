{ ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      packagesDir = ../packages;
      names = builtins.attrNames (builtins.readDir packagesDir);
    in
    {
      packages = lib.genAttrs names (name: pkgs.callPackage (packagesDir + "/${name}") { });
    };
}
