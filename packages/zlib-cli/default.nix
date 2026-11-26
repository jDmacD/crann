# zlib (github.com/heartleo/zlib): a Z-Library CLI, TUI and stdio MCP server
# (`zlib mcp`). Built from source rather than the release binary or the
# self-installing agent plugin. `zlib update` replaces only binaries it
# installed itself, so it leaves this one alone; bump `version` here instead.
{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
let
  version = "0.0.16";
in
buildGoModule {
  pname = "zlib-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "heartleo";
    repo = "zlib";
    tag = "v${version}";
    hash = "sha256-RPzenQ/fxddo46Wzsij+YVqAOomsSN8meXyFwPC2aAA=";
  };

  vendorHash = "sha256-UmHkKNBEf6Phjnd9UwU7kj31JPKtiqxUazQ6Fov+WXU=";

  subPackages = [ "cmd/zlib" ];

  env.CGO_ENABLED = 0;

  # Upstream's GoReleaser ldflags; zlib reports versions as vX.Y.Z.
  ldflags = [
    "-s"
    "-w"
    "-X github.com/heartleo/zlib/internal/zlib.Version=v${version}"
  ];

  meta = {
    description = "Z-Library CLI: search, download, metadata, MCP server";
    homepage = "https://github.com/heartleo/zlib";
    license = lib.licenses.mit;
    # Upstream releases linux and darwin builds (pure Go, CGO off).
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "zlib";
  };
}
