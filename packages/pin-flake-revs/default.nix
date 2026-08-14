{
  lib,
  writers,
  runCommand,
  makeWrapper,
  git,
}:
let
  script = writers.writePython3Bin "pin-flake-revs" { } (builtins.readFile ./pin-flake-revs.py);
in
runCommand script.name { nativeBuildInputs = [ makeWrapper ]; } ''
  makeWrapper ${script}/bin/pin-flake-revs $out/bin/pin-flake-revs \
    --prefix PATH : ${lib.makeBinPath [ git ]}
''
