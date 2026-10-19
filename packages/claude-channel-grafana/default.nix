# Keep @modelcontextprotocol/sdk on 1.x: Claude Code's v2 MCP runtime won't
# register a channel server that negotiates protocol revision 2026-07-28,
# which SDK 2.x does. https://code.claude.com/docs/en/mcp
#
# package.json's postinstall feeds bun2nix a lockfileVersion-1 copy of
# bun.lock, since bun2nix 2.1.2's CLI rejects v2 (the layout it reads is the
# same). Drop that once nix-community/bun2nix#110 is released.
{ bun2nix }:
bun2nix.mkDerivation {
  packageJson = ./package.json;
  src = ./.;
  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./bun.nix;
  };
  meta.mainProgram = "claude-channel-grafana";
}
