"""noctalia-capture: turn Noctalia GUI changes into declarative config.

Noctalia merges, lowest first: built-in defaults, ~/.config/noctalia/*.toml
(config.toml, desktop.toml, host.toml), then the GUI's settings.toml. This
tool exports the merged config twice, with and without the GUI layer, and
diffs them. What the GUI adds or overrides is split into:

  shared      safe to put in the shared desktop.toml for every host
  host-local  tied to this machine (outputs, devices, store paths, secrets)

Usage:
  noctalia-capture                 show shared and host-local GUI changes
  noctalia-capture --write FILE    merge the shared changes into FILE
                                   (the repo's desktop.toml)
  noctalia-capture --prune         drop GUI keys that now equal the declared
                                   value (run after rebuilding with FILE)
  noctalia-capture --share PREFIX  treat keys under PREFIX as shared anyway
                                   (dotted, e.g. wallpaper.monitor)

Typical round trip: tweak in the GUI, `--write`, commit, rebuild, `--prune`.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import tomllib

NOCTALIA = os.environ.get("NOCTALIA_BIN", "noctalia")
REMARSHAL = os.environ.get("REMARSHAL_BIN", "remarshal")

# Key paths (as tuples, "*" matches one segment) that describe this machine
# rather than the desktop. A key is host-local when its path starts with one.
HOST_PREFIXES = [
    ("lockscreen_widgets", "widget"),  # keyed by connector, absolute pixels
    ("lockscreen_widgets", "widget_order"),
    ("desktop_widgets", "widget"),
    ("desktop_widgets", "widget_order"),
    ("wallpaper", "default"),  # current picture
    ("wallpaper", "last"),
    ("wallpaper", "monitors"),  # current picture per output
    ("wallpaper", "monitor"),  # per-output folders
    ("bar", "*", "monitor"),  # per-output bar overrides
    ("battery", "device"),  # per-device thresholds
    ("calendar", "accounts"),
    ("*", "schema_version"),  # Noctalia's own markers
    ("config_version",),
]
# Credentials stay out of the repo. Plugin settings are otherwise shared (every
# desktop runs the same wallpaper setup); `*_file` paths such as api_key_file
# are shared, the inline secrets they point at are not.
SECRET_KEY = re.compile(r"(^|_)(api_?key|token|password|secret|server_url)$", re.I)


def export(state_home=None):
    env = dict(os.environ)
    if state_home is not None:
        env["NOCTALIA_STATE_HOME"] = state_home
    out = subprocess.run(
        [NOCTALIA, "config", "export", "merged", "--credentials", "keep"],
        env=env,
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return tomllib.loads(out)


def flatten(table, prefix=()):
    for key, value in table.items():
        path = prefix + (key,)
        if isinstance(value, dict):
            yield from flatten(value, path)
        else:
            yield path, value


def starts_with(path, prefix):
    if len(path) < len(prefix):
        return False
    return all(p == "*" or p == k for p, k in zip(prefix, path))


def has_store_path(value):
    if isinstance(value, str):
        return "/nix/store/" in value
    if isinstance(value, list):
        return any(has_store_path(v) for v in value)
    if isinstance(value, dict):
        return any(has_store_path(v) for v in value.values())
    return False


def host_reason(path, value, shared_prefixes):
    if any(starts_with(path, p) for p in shared_prefixes):
        return None
    for prefix in HOST_PREFIXES:
        if starts_with(path, prefix):
            return ".".join(prefix)
    if SECRET_KEY.search(path[-1]):
        return "credential"
    if has_store_path(value):
        return "/nix/store path"
    return None


def dotted(path):
    return ".".join(f'"{k}"' if re.search(r"[^A-Za-z0-9_-]", k) else k for k in path)


def set_path(table, path, value):
    for key in path[:-1]:
        table = table.setdefault(key, {})
    table[path[-1]] = value


def del_path(table, path):
    trail = []
    for key in path[:-1]:
        if not isinstance(table.get(key), dict):
            return False
        trail.append((table, key))
        table = table[key]
    if path[-1] not in table:
        return False
    del table[path[-1]]
    for parent, key in reversed(trail):  # drop tables left empty
        if parent[key]:
            break
        del parent[key]
    return True


def to_toml(table):
    return subprocess.run(
        [REMARSHAL, "--if", "json", "--of", "toml"],
        input=json.dumps(table),
        capture_output=True,
        text=True,
        check=True,
    ).stdout


def write_toml(path, table, header=""):
    body = to_toml(table) if table else ""
    if header and body and not header.endswith("\n\n"):
        header += "\n"
    tmp = f"{path}.tmp-capture"
    with open(tmp, "w") as f:
        f.write(header + body)
    os.replace(tmp, path)


def settings_path():
    base = (
        os.environ.get("NOCTALIA_STATE_HOME")
        or os.environ.get("XDG_STATE_HOME")
        or os.path.expanduser("~/.local/state")
    )
    return os.path.join(base, "noctalia", "settings.toml")


def leading_comments(path):
    lines = []
    with open(path) as f:
        for line in f:
            if line.startswith("#") or not line.strip():
                lines.append(line)
            else:
                break
    return "".join(lines)


def main():
    ap = argparse.ArgumentParser(
        prog="noctalia-capture",
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--write", metavar="FILE", help="merge shared changes into FILE")
    ap.add_argument(
        "--prune", action="store_true", help="drop GUI keys equal to the declared value"
    )
    ap.add_argument(
        "--share",
        metavar="PREFIX",
        action="append",
        default=[],
        help="treat keys under this dotted prefix as shared",
    )
    args = ap.parse_args()
    shared_prefixes = [tuple(p.split(".")) for p in args.share]

    merged = dict(flatten(export()))
    with tempfile.TemporaryDirectory() as empty:
        declared = dict(flatten(export(state_home=empty)))

    shared, local = {}, {}
    for path, value in sorted(merged.items()):
        if path in declared and declared[path] == value:
            continue
        reason = host_reason(path, value, shared_prefixes)
        (local if reason else shared)[path] = (value, reason)

    if args.prune:
        sp = settings_path()
        with open(sp, "rb") as f:
            gui = tomllib.load(f)
        dropped = [
            path
            for path, value in list(flatten(gui))
            if path in declared and declared[path] == value
        ]
        for path in dropped:
            del_path(gui, path)
        if dropped:
            write_toml(sp, gui)
        for path in dropped:
            print(f"pruned  {dotted(path)}")
        print(f"{len(dropped)} redundant GUI key(s) removed from {sp}")
        return

    print(f"# {len(shared)} shared GUI change(s)")
    for path, (value, _) in shared.items():
        note = "  # overrides a declared value" if path in declared else ""
        print(f"{dotted(path)} = {json.dumps(value)}{note}")
    if local:
        print(f"\n# {len(local)} host-local GUI change(s), kept out of desktop.toml")
        groups = {}
        for path, (_, reason) in local.items():
            groups.setdefault(reason, []).append(path)
        for reason, paths in groups.items():
            print(f"#   {reason}: {len(paths)} key(s), e.g. {dotted(paths[0])}")

    if args.write:
        target = {}
        header = ""
        if os.path.exists(args.write):
            with open(args.write, "rb") as f:
                target = tomllib.load(f)
            header = leading_comments(args.write)
        for path, (value, _) in shared.items():
            set_path(target, path, value)
        write_toml(args.write, target, header)
        print(f"\nwrote {len(shared)} key(s) into {args.write}")
        print("commit it, rebuild, then run `noctalia-capture --prune`")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        sys.exit(f"{e.cmd[0]} failed: {e.stderr.strip()}")
