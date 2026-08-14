{
  lib,
  writers,
  runCommand,
  makeWrapper,
  git,
}:
let
  script = writers.writePython3Bin "sync-flake-revs" { } (builtins.readFile ./sync-flake-revs.py);
in
runCommand script.name { nativeBuildInputs = [ makeWrapper ]; } ''
  makeWrapper ${script}/bin/sync-flake-revs $out/bin/sync-flake-revs \
    --prefix PATH : ${lib.makeBinPath [ git ]}
''
