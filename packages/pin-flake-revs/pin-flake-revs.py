import json
import re
import subprocess

REV_RE = re.compile(r"[0-9a-f]{7,40}")


def get_root():
    return subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()


def load_locked_revs(root):
    with open(f"{root}/flake.lock") as f:
        lock = json.load(f)
    nodes = lock["nodes"]
    revs = {}
    for name, node_ref in nodes["root"]["inputs"].items():
        node = node_ref if isinstance(node_ref, str) else node_ref[-1]
        rev = nodes[node].get("locked", {}).get("rev")
        if rev:
            revs[name] = rev
    return revs


def is_pinned(url):
    if re.search(r"[?&]rev=[0-9a-f]{7,40}", url):
        return True
    m = re.match(r"github:[^/]+/[^/]+/([^?]+)", url)
    return bool(m and REV_RE.fullmatch(m.group(1)))


def pin_url(url, rev):
    """Add `?rev=` to a github: url, dropping any ref/branch pin.

    Nix refuses a flakeref that carries both a rev and a ref, so
    an existing `?ref=x` query param or `/branch` path segment is
    dropped in favor of the exact commit.
    """
    m = re.match(r"^(github:[^/]+/[^/?]+)(?:/([^?]+))?(?:\?(.*))?$", url)
    if not m:
        return None

    base, path_ref, query = m.groups()
    has_rev = path_ref and REV_RE.fullmatch(path_ref)
    dropped_ref = path_ref if path_ref and not has_rev else None

    params = []
    for part in (query or "").split("&"):
        if not part:
            continue
        key = part.split("=", 1)[0]
        if key == "ref":
            dropped_ref = dropped_ref or part.split("=", 1)[-1]
            continue
        params.append(part)
    params.append(f"rev={rev}")

    return f"{base}?{'&'.join(params)}", dropped_ref


def main():
    root = get_root()
    revs = load_locked_revs(root)

    flake_nix = f"{root}/flake.nix"
    with open(flake_nix) as f:
        text = f.read()

    current = None
    out_lines = []
    for line in text.splitlines(keepends=True):
        m = re.match(r'\s*([A-Za-z0-9_-]+)\.url\s*=\s*"', line)
        if not m:
            m = re.match(r"\s*([A-Za-z0-9_-]+)\s*=\s*\{", line)
        if m:
            current = m.group(1)

        if current in revs and "url" in line:
            url_match = re.search(r'"([^"]+)"', line)
            if url_match:
                url = url_match.group(1)
                if url.startswith("github:") and not is_pinned(url):
                    pinned = pin_url(url, revs[current])
                    if pinned:
                        new_url, dropped_ref = pinned
                        line = line.replace(url, new_url)
                        note = ""
                        if dropped_ref:
                            note = f" (dropped ref '{dropped_ref}')"
                        print(f"pinned {current} -> {revs[current]}{note}")

        out_lines.append(line)

    with open(flake_nix, "w") as f:
        f.write("".join(out_lines))


if __name__ == "__main__":
    main()
