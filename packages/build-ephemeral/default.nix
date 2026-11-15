# Run a command with a temporary Hetzner Cloud server as the only remote
# builder for one architecture, then delete the server.
#
#   build-ephemeral nix build .#deploy.nodes.pi04.profiles.system.path
#   ARCH=x86_64-linux build-ephemeral nh os build .
#
# Boots the newest snapshot labelled role=<arm|x86>-builder (blueprint's
# `nix run .#snapshot-builder -- <arm|x86>`), points Nix at it through
# NIX_CONFIG, runs the command, and deletes the server on exit, also on
# failure or Ctrl-C. Results come back to this host's store.
#
# Server choice: every current Hetzner type for the architecture with at
# least MIN_CORES cores and at most MAX_PRICE €/h (gross), most cores first,
# then cheapest; each type is tried in every location that sells it
# (PREFER_LOCATION first) before stepping down, since capacity often runs
# out (resource_unavailable).
#
# The client's daemon logs in as `builder` with SSH_KEY, and pins the host
# key that snapshot-builder writes into the snapshot's description. With
# ARCH=x86_64-linux the local host builds nothing (max-jobs = 0) unless
# LOCAL_JOBS is set to something other than 0.
{
  writeShellApplication,
  hcloud,
  jq,
  openssh,
  coreutils,
  gnugrep,
}:
writeShellApplication {
  name = "build-ephemeral";
  runtimeInputs = [
    hcloud
    jq
    openssh
    coreutils
    gnugrep
  ];
  text = ''
    if [ $# -eq 0 ]; then
      echo "usage: [ARCH=aarch64-linux|x86_64-linux] build-ephemeral <command> [args...]" >&2
      exit 2
    fi
    ARCH=''${ARCH:-aarch64-linux}
    case "$ARCH" in
      aarch64-linux) role=arm-builder hcloud_arch=arm default_min=4 ;;
      x86_64-linux) role=x86-builder hcloud_arch=x86 default_min=16 ;;
      *)
        echo "build-ephemeral: ARCH must be aarch64-linux or x86_64-linux" >&2
        exit 2
        ;;
    esac
    # Below this a temporary server isn't worth it: 4 = worf (cax21) for arm,
    # 16 = picard's thread count for x86.
    MIN_CORES=''${MIN_CORES:-$default_min}
    MAX_PRICE=''${MAX_PRICE:-0.30}
    PREFER_LOCATION=''${PREFER_LOCATION:-hel1}
    SSH_KEY=''${SSH_KEY:-/run/secrets/builder_ed25519}

    image_json=$(hcloud image list --type snapshot --selector "role=$role" -o json \
      | jq 'max_by(.created) // empty')
    if [ -z "$image_json" ]; then
      echo "build-ephemeral: no role=$role snapshot; run blueprint's snapshot-builder" >&2
      exit 1
    fi
    IMAGE=$(jq -r .id <<<"$image_json")
    hostkey=$(jq -r .description <<<"$image_json" | grep -oE 'ssh-ed25519 [A-Za-z0-9+/=]+' || true)
    if [ -z "$hostkey" ]; then
      echo "build-ephemeral: snapshot $IMAGE has no ssh-ed25519 host key in its description" >&2
      exit 1
    fi
    NAME="$role-$(date -u +%Y%m%d%H%M%S)"

    cleanup() {
      if hcloud server describe "$NAME" >/dev/null 2>&1; then
        echo "build-ephemeral: deleting $NAME" >&2
        hcloud server delete "$NAME" >/dev/null
      fi
    }
    trap cleanup EXIT
    trap 'exit 130' INT TERM

    # One "<type> <cores> <location> <price>" line per candidate, in order.
    candidates=$(hcloud server-type list -o json | jq -r \
      --arg arch "$hcloud_arch" --argjson min "$MIN_CORES" \
      --argjson max "$MAX_PRICE" --arg pref "$PREFER_LOCATION" '
        [ .[] | select(.architecture == $arch and .deprecation == null and .cores >= $min)
          | . as $t
          # .prices still lists locations a type can no longer be ordered in
          # (deprecated per location); skip those. .available is live
          # capacity: try those locations first, the rest after (a refused
          # create costs a second, and the flag may lag).
          | ([ .locations[]? | select(.deprecation == null)
               | { key: .name, value: .available } ] | from_entries) as $locs
          | .prices[]
          | .location as $l
          | select($locs | has($l))
          | (.price_hourly.gross | tonumber) as $p
          | select($p <= $max)
          | { name: $t.name, cores: $t.cores, loc: .location, price: $p,
              avail: $locs[.location] } ]
        | sort_by(-.cores, (if .avail then 0 else 1 end), .price,
            (if .loc == $pref then 0 else 1 end))[]
        | "\(.name) \(.cores) \(.loc) \(.price)"')
    if [ -z "$candidates" ]; then
      echo "build-ephemeral: no $hcloud_arch type with >= $MIN_CORES cores under €$MAX_PRICE/h" >&2
      exit 1
    fi

    created="" cores=0
    while read -r type ncores loc price; do
      echo "build-ephemeral: trying $type ($ncores cores, €$price/h) in $loc" >&2
      if err=$(hcloud server create --name "$NAME" --type "$type" --image "$IMAGE" \
        --location "$loc" --without-ipv6 --label role="$role-run" 2>&1 >/dev/null); then
        created="$type/$loc" cores=$ncores
        break
      fi
      echo "build-ephemeral:   $(tail -1 <<<"$err")" >&2
    done <<<"$candidates"
    if [ -z "$created" ]; then
      echo "build-ephemeral: no capacity for any candidate" >&2
      exit 1
    fi
    # Each job gets all cores (cores = 0 on the builder); a few at once keep
    # small derivations moving beside a big one.
    JOBS=''${JOBS:-$((cores >= 8 ? cores / 4 : 2))}
    IP=$(hcloud server ip "$NAME")
    echo "build-ephemeral: got $created ($cores cores, $JOBS jobs) at $IP" >&2

    got=""
    for _ in $(seq 60); do
      got=$(ssh-keyscan -t ed25519 "$IP" 2>/dev/null | grep -v '^#' | cut -d" " -f2-3 || true)
      [ -n "$got" ] && break
      sleep 5
    done
    if [ -z "$got" ]; then
      echo "build-ephemeral: no SSH on $IP after 10 min; did $created boot the image?" >&2
      exit 1
    fi
    if [ "$got" != "$hostkey" ]; then
      echo "build-ephemeral: host key mismatch on $IP (got '$got', snapshot says '$hostkey')" >&2
      exit 1
    fi

    features=big-parallel,kvm,nixos-test,benchmark
    hostkey_b64=$(printf '%s\n' "$hostkey" | base64 -w0)
    export NIX_CONFIG="builders = ssh-ng://builder@$IP $ARCH $SSH_KEY $JOBS 1 $features - $hostkey_b64
    builders-use-substitutes = true
    ''${NIX_CONFIG:-}"
    # x86 hosts could build locally, which defeats the point (keeping load
    # off picard), so by default nothing builds here.
    if [ "$ARCH" = x86_64-linux ] && [ "''${LOCAL_JOBS:-0}" = 0 ]; then
      NIX_CONFIG="$NIX_CONFIG
    max-jobs = 0"
    fi
    echo "build-ephemeral: running: $*" >&2
    "$@"
  '';
}
