{ inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      packagesDir = ../packages;
      names = builtins.attrNames (builtins.readDir packagesDir);
      # Packages that ask for `bun2nix` get crann's pinned copy rather than
      # one from the consumer's nixpkgs (bun2nix isn't in nixpkgs).
      extraArgs = {
        bun2nix = inputs.bun2nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };
      callPackage =
        path: pkgs.callPackage path (builtins.intersectAttrs (lib.functionArgs (import path)) extraArgs);
    in
    {
      packages = lib.genAttrs names (name: callPackage (packagesDir + "/${name}"));
    };
}
