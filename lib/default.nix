{
  nixpkgs,
  harbor-meta,
}: rec {
  timezone = harbor-meta.lib.timezone;

  # ponytail: Nixpkgs' cargoSetupHook forces system libraries (44cddf9), but
  # foundry 1.8.6 declares none of the AWS-LC, zstd, SQLite and jemalloc its
  # -sys crates now require, so it fails to build (uncached upstream). Drop
  # once Nixpkgs declares them.
  fixFoundry = pkgs:
    pkgs.foundry.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.pkg-config];
      buildInputs = (old.buildInputs or []) ++ [pkgs.aws-lc pkgs.zstd pkgs.sqlite pkgs.rust-jemalloc-sys];
    });
  foundryOverlay = final: prev: {foundry = fixFoundry prev;};
  mkEthToolchain = {
    pkgs,
    foundry ? fixFoundry pkgs,
    solc ? pkgs.solc,
  }: {
    packages = [foundry solc];
    env = {
      FOUNDRY_SOLC = "${solc}/bin/solc";
      FOUNDRY_VERSION = foundry.version;
      SOLC_VERSION = solc.version;
    };
  };

  mkEthDevShellFragment = args: let
    toolchain = mkEthToolchain args;
  in {
    inherit (toolchain) packages env;
    shellHook = "";
  };

  mkEthDevShell = {
    pkgs,
    timeZone ? "UTC",
    ...
  } @ args:
    harbor-meta.lib.devShell.mkShell {
      inherit pkgs timeZone;
      fragments = [
        (mkEthDevShellFragment (builtins.removeAttrs args ["timeZone"]))
      ];
    };
}
