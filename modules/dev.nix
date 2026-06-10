# dev.nix — general-purpose development toolchains baked into every luna-os
# variant. Userspace only and kernel-agnostic: imported by modules/luna.nix so
# the daily driver, the lab system, and all six ISOs ship the same languages.
#
# Toolchains come from nixpkgs (pinned by the flake), so they're reproducible
# and versioned with everything else. Project-specific toolchains should still
# live in a per-project devshell/flake — this is just a comfortable global base.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # ---- Rust ----
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer

    # ---- Python ---- (one interpreter carrying pip + virtualenv)
    (python3.withPackages (ps: with ps; [ pip virtualenv ]))

    # ---- C / C++ ----
    gcc # cc / gcc / g++
    clang-tools # clangd + clang-format + clang-tidy (no `cc`, so no gcc clash)
    gnumake
    cmake
    gdb
    pkg-config
    binutils

    # ---- Go ----
    go
    gopls

    # ---- Node.js / TypeScript ---- (nodePackages.* was removed upstream; the
    # tooling lives at top level now — tsx is the maintained ts-node successor)
    nodejs
    typescript
    tsx
  ];
}
