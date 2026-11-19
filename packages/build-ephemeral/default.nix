# Run a command with a temporary cloud server as the only remote builder for
# one architecture, then delete the server.
#
#   build-ephemeral nix build .#deploy.nodes.pi04.profiles.system.path
#   ARCH=x86_64-linux build-ephemeral nh os build .
#
# Boots the newest image labelled role=<arm|x86>-builder (blueprint's
# `nix run .#snapshot-builder -- <arm|x86> [hetzner|scaleway]`), points Nix at
# it through NIX_CONFIG, runs the command, and deletes the server on exit,
# also on failure or Ctrl-C. Results come back to this host's store.
#
# Providers are tried in PROVIDERS order (default "hetzner scaleway"); one is
# skipped when it has no image for the architecture (Scaleway: arm only) or
# its CLI has no credentials.
#
#   Hetzner   every current type for the architecture with at least
#             MIN_CORES cores and at most MAX_PRICE €/h (gross), most cores
#             first, then cheapest; each type is tried in every location that
#             sells it (PREFER_LOCATION first) before stepping down, since
#             capacity often runs out (resource_unavailable).
#   Scaleway  the same filter over SCW_ZONE's (nl-ams-1) types, with a
#             SCW_ROOT_GB (60) Block Storage root volume; the image grows into
#             it. Creates over the project's quota fail fast and fall through.
#
# The client's daemon logs in as `builder` with SSH_KEY, and pins the host
# key that snapshot-builder records with the image. With ARCH=x86_64-linux
# the local host builds nothing (max-jobs = 0) unless LOCAL_JOBS is set to
# something other than 0.
{
  writeShellApplication,
  hcloud,
  scaleway-cli,
  jq,
  openssh,
  coreutils,
  gnugrep,
}:
writeShellApplication {
  name = "build-ephemeral";
  runtimeInputs = [
    hcloud
    scaleway-cli
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
      aarch64-linux) role=arm-builder hcloud_arch=arm scw_arch=arm64 default_min=4 ;;
      x86_64-linux) role=x86-builder hcloud_arch=x86 scw_arch=x86_64 default_min=16 ;;
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
    PROVIDERS=''${PROVIDERS:-hetzner scaleway}
    SCW_ZONE=''${SCW_ZONE:-nl-ams-1}
    SCW_ROOT_GB=''${SCW_ROOT_GB:-60}
    SSH_KEY=''${SSH_KEY:-/run/secrets/builder_ed25519}
    NAME="$role-$(date -u +%Y%m%d%H%M%S)"

    log() { echo "build-ephemeral: $*" >&2; }

    # Each provider has: <p>_image (sets IMAGE and HOSTKEY, fails if there is
    # none), <p>_candidates ("<type> <cores> <location> <price>" lines, in
    # order), <p>_create <type> <location> (sets IP), <p>_delete.

    # --- Hetzner -------------------------------------------------------------
    hetzner_image() {
      local json
      json=$(hcloud image list --type snapshot --selector "role=$role" -o json) || return 1
      json=$(jq 'max_by(.created) // empty' <<<"$json")
      [ -n "$json" ] || return 1
      IMAGE=$(jq -r .id <<<"$json")
      HOSTKEY=$(jq -r .description <<<"$json" | grep -oE 'ssh-ed25519 [A-Za-z0-9+/=]+' || true)
    }
    hetzner_candidates() {
      hcloud server-type list -o json | jq -r \
        --arg arch "$hcloud_arch" --argjson min "$MIN_CORES" \
        --argjson max "$MAX_PRICE" --arg pref "$PREFER_LOCATION" '
          [ .[] | select(.architecture == $arch and .deprecation == null and .cores >= $min)
            | . as $t
            # .prices still lists locations a type can no longer be ordered
            # in (deprecated per location); skip those. .available is live
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
          | "\(.name) \(.cores) \(.loc) \(.price)"'
    }
    hetzner_create() {
      hcloud server create --name "$NAME" --type "$1" --image "$IMAGE" \
        --location "$2" --without-ipv6 --label role="$role-run" >/dev/null || return 1
      IP=$(hcloud server ip "$NAME")
    }
    hetzner_delete() {
      if hcloud server describe "$NAME" >/dev/null 2>&1; then
        log "deleting $NAME (hetzner)"
        hcloud server delete "$NAME" >/dev/null
      fi
    }

    # --- Scaleway ------------------------------------------------------------
    SCW_SERVER_ID=""
    scaleway_image() {
      local json
      json=$(scw instance image list zone="$SCW_ZONE" -o json) || return 1
      json=$(jq --arg r "role=$role" --arg a "$scw_arch" '
        map(select((.tags // [] | index($r)) and .arch == $a and .state == "available"))
        | max_by(.creation_date) // empty' <<<"$json")
      [ -n "$json" ] || return 1
      IMAGE=$(jq -r .id <<<"$json")
      HOSTKEY=$(jq -r '.tags[] | select(startswith("hostkey=")) | "ssh-ed25519 " + .[8:]' <<<"$json" || true)
    }
    scaleway_candidates() {
      scw instance server-type list zone="$SCW_ZONE" -o json | jq -r \
        --arg arch "$scw_arch" --argjson min "$MIN_CORES" --argjson max "$MAX_PRICE" \
        --arg zone "$SCW_ZONE" '
          [ .[] | select(.arch == $arch and .cpu >= $min and .end_of_service != true
                         and .availability != "shortage")
            | { name, cores: .cpu,
                price: ((.hourly_price.units | tonumber) + .hourly_price.nanos / 1e9) }
            | select(.price <= $max) ]
          | sort_by(-.cores, .price)[]
          | "\(.name) \(.cores) \($zone) \(.price)"'
    }
    scaleway_create() {
      SCW_SERVER_ID=$(scw instance server create zone="$2" name="$NAME" type="$1" \
        image="$IMAGE" root-volume="sbs:''${SCW_ROOT_GB}GB" ip=ipv4 \
        tags.0="role=$role-run" -o json | jq -r .id) || return 1
      scw instance server wait "$SCW_SERVER_ID" zone="$2" >/dev/null
      IP=$(scw instance server get "$SCW_SERVER_ID" zone="$2" -o json \
        | jq -r '.public_ips[0].address // .public_ip.address')
    }
    scaleway_delete() {
      # A create that failed after the API accepted it leaves no ID; find it.
      [ -n "$SCW_SERVER_ID" ] || SCW_SERVER_ID=$(scw instance server list zone="$SCW_ZONE" \
        name="$NAME" -o json 2>/dev/null | jq -r --arg n "$NAME" \
        '[.[] | select(.name == $n)][0].id // empty')
      if [ -n "$SCW_SERVER_ID" ] && scw instance server get "$SCW_SERVER_ID" zone="$SCW_ZONE" >/dev/null 2>&1; then
        log "deleting $NAME (scaleway)"
        scw instance server delete "$SCW_SERVER_ID" zone="$SCW_ZONE" \
          with-volumes=all with-ip=true force-shutdown=true >/dev/null
      fi
    }

    tried=""
    errf=$(mktemp)
    cleanup() {
      rm -f "$errf"
      for p in $tried; do "''${p}_delete" || true; done
    }
    trap cleanup EXIT
    trap 'exit 130' INT TERM

    created="" cores=0
    for p in $PROVIDERS; do
      case "$p" in hetzner | scaleway) ;; *)
        log "unknown provider '$p' in PROVIDERS"
        exit 2
        ;;
      esac
      IMAGE="" HOSTKEY=""
      if ! "''${p}_image" 2>/dev/null; then
        log "$p: no role=$role image (or no credentials); skipping"
        continue
      fi
      if [ -z "$HOSTKEY" ]; then
        log "$p: image $IMAGE has no ssh-ed25519 host key recorded; skipping"
        continue
      fi
      candidates=$("''${p}_candidates") || candidates=""
      if [ -z "$candidates" ]; then
        log "$p: no $ARCH type with >= $MIN_CORES cores under €$MAX_PRICE/h"
        continue
      fi
      tried="$tried $p"
      while read -r type ncores loc price; do
        log "$p: trying $type ($ncores cores, €$price/h) in $loc"
        # Not in a subshell: _create sets IP (and the server ID).
        if "''${p}_create" "$type" "$loc" 2>"$errf" >/dev/null; then
          created="$p $type/$loc" cores=$ncores
          break
        fi
        log "  $(tail -1 "$errf")"
      done <<<"$candidates"
      [ -n "$created" ] && break
    done
    if [ -z "$created" ]; then
      log "no capacity with any provider ($PROVIDERS)"
      exit 1
    fi
    # Each job gets all cores (cores = 0 on the builder); a few at once keep
    # small derivations moving beside a big one.
    JOBS=''${JOBS:-$((cores >= 8 ? cores / 4 : 2))}
    log "got $created ($cores cores, $JOBS jobs) at $IP"

    got=""
    for _ in $(seq 60); do
      got=$(ssh-keyscan -t ed25519 "$IP" 2>/dev/null | grep -v '^#' | cut -d" " -f2-3 || true)
      [ -n "$got" ] && break
      sleep 5
    done
    if [ -z "$got" ]; then
      log "no SSH on $IP after 10 min; did $created boot the image?"
      exit 1
    fi
    if [ "$got" != "$HOSTKEY" ]; then
      log "host key mismatch on $IP (got '$got', image says '$HOSTKEY')"
      exit 1
    fi

    features=big-parallel,kvm,nixos-test,benchmark
    hostkey_b64=$(printf '%s\n' "$HOSTKEY" | base64 -w0)
    export NIX_CONFIG="builders = ssh-ng://builder@$IP $ARCH $SSH_KEY $JOBS 1 $features - $hostkey_b64
    builders-use-substitutes = true
    ''${NIX_CONFIG:-}"
    # x86 hosts could build locally, which defeats the point (keeping load
    # off picard), so by default nothing builds here.
    if [ "$ARCH" = x86_64-linux ] && [ "''${LOCAL_JOBS:-0}" = 0 ]; then
      NIX_CONFIG="$NIX_CONFIG
    max-jobs = 0"
    fi
    log "running: $*"
    "$@"
  '';
}
