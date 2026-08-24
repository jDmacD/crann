import json
import re
import subprocess


def main():
    root = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()

    with open(f"{root}/flake.lock") as f:
        lock = json.load(f)

    nodes = lock["nodes"]
    root_inputs = nodes["root"]["inputs"]

    revs = {}
    for name, node_ref in root_inputs.items():
        node = node_ref if isinstance(node_ref, str) else node_ref[-1]
        locked = nodes[node].get("locked", {})
        rev = locked.get("rev")
        if rev:
            revs[name] = rev

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

        if current in revs and "url" in line and '"' in line:
            rev = revs[current]
            new_line = re.sub(r"\?rev=[0-9a-f]{7,40}", f"?rev={rev}", line)
            path_pin = r'(github:[^"?]+/)[0-9a-f]{7,40}(")'
            new_line = re.sub(path_pin, rf"\g<1>{rev}\g<2>", new_line)
            if new_line != line:
                print(f"synced {current} -> {rev}")
            line = new_line

        out_lines.append(line)

    with open(flake_nix, "w") as f:
        f.write("".join(out_lines))


if __name__ == "__main__":
    main()
