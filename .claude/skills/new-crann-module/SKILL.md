---
name: new-crann-module
description: Scaffold a new crann feature module (homeManager or nixos class) with the repo's jinja2 templates, fill it in per crann's conventions, and wire it into the test host for validation. Use whenever adding a new reusable module under modules/home/ or modules/nixos/.
argument-hint: <homeManager|nixos> <name>
---

# New crann module

Scaffolds a module the way `new-homemanager`/`new-nixos` (the devShell scripts in
`modules/shells/default.nix`) already do, then carries the work through to a
finished, validated module. Read `CLAUDE.md` at the repo root first if it isn't
already in context — every convention below is defined there in full.

Args are `<class> <name>`, e.g. `nixos wireguard` or `homeManager firefox`. If
either is missing, ask before proceeding — don't guess a name. `darwin` has no
scaffolding branch yet in `modules/templates/_module.nix`; if asked for a darwin
module, say so and offer to add the branch first rather than generating an empty
shell.

## Steps

1. **Generate.** From the repo root:
   ```
   nix develop -c new-homemanager <name>    # homeManager class
   nix develop -c new-nixos <name>          # nixos class
   ```
   This renders `modules/templates/_module.nix` into `modules/home/<name>.nix` or
   `modules/nixos/<name>.nix`, runs `treefmt` on it, and `git add`s it. Entering
   the devShell may need to realize `jinja2-cli`/`treefmt` once; that's a normal
   shell activation, not a full system build.

2. **Fill in the real option surface.** The generated file has a working
   `packages`/`extraPackages` pair (defaulting to `pkgs.hello`) and a commented
   stanza (`package`, `extraSettings`, and — for nixos — `user`) as a starting
   point, not a finished module. Uncomment and adapt what the feature actually
   needs; delete what it doesn't. If the feature needs more than that — an enum,
   a nullable option, a `lib.mkMerge` over `extraSettings` — copy the relevant
   pattern from `modules/features/_skeleton.nix` rather than inventing new shape.
   Every option stays namespaced under `options.crann.<name>`.

3. **Wire real config**, still under `config = lib.mkIf cfg.enable { ... };`.
   Apply the portability rules from CLAUDE.md as you write it:
   - No `nixpkgs.overlays` / `nixpkgs.config` anywhere in the module.
   - Pull inputs via closure (the outer `{ inputs, ... }:`), never add `inputs`
     to the inner module's argument list.
   - Any package that isn't plain `pkgs.foo` should come straight from a crann
     input (`inputs.foo.packages.${pkgs.stdenv.hostPlatform.system}...`), and be
     exposed through the `package` option so a host can override it.
   - Don't reach for options that only exist in one home-manager mode (e.g.
     `home.stateVersion` belongs to the host).

4. **Wire it into the test host** (`modules/hosts/test.nix`) so it's actually
   exercised:
   - homeManager class → add `config.flake.modules.homeManager.<name>` to the
     relevant `imports` list(s) (`flake.homeConfigurations.test-home` and/or the
     `home-manager.users.test.imports` inside `nixosConfigurations.test`) and set
     `crann.<name>.enable = true;` plus whatever fixture values the options need.
   - nixos class → add `config.flake.modules.nixos.<name>` to the
     `flake.nixosConfigurations.test` modules list and set `crann.<name>.enable`
     there.
   - Keep fixture values minimal — just enough to make the module's options
     concrete, matching the style of the existing entries in that file.

5. **Validate cheaply first.** Prefer `nix eval` over a full build:
   ```
   nix eval .#homeConfigurations.test-home.config.crann.<name>.enable
   nix eval .#nixosConfigurations.test.config.crann.<name>.enable
   ```
   Don't run `nix build` or `nix flake check` without asking first.

6. **Format** with `nix fmt` before calling it done. Files are already staged by
   the scaffold script; don't `git commit` unless the user explicitly asks.

## Notes

- The scaffold script only takes `<name>` — no extra flags. That's deliberate:
  the commented-out stanzas exist so step 2 happens by hand, not so the script
  guesses which options a feature needs. Don't extend the shell script's
  parameters to work around this; extend the template or follow
  `_skeleton.nix` instead.
