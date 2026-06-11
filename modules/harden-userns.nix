# harden-userns.nix — headless-only hardening.
#
# The lab kernel ships CONFIG_USER_NS=y because the DESKTOP variants need
# unprivileged user namespaces for Chromium's sandbox (the Electron app). The
# headless/terminal variants don't run a browser, so we re-close that surface
# here at runtime instead of compiling it out — one kernel, policy per variant.
#
# Trade-off (intentional): nix's *build* sandbox also uses user namespaces, so
# on these headless variants nix falls back to non-sandboxed builds. Acceptable
# for the server profile; desktop variants keep both sandboxes.
{ lib, ... }:
{
  boot.kernel.sysctl."user.max_user_namespaces" = lib.mkDefault 0;
}
