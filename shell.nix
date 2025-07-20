{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.linuxPackages_latest.kernel.dev
    pkgs.gcc
    pkgs.gnumake
  ];

  shellHook = ''
    export KERNEL_DIR=${pkgs.linuxPackages_latest.kernel.dev}/lib/modules/${pkgs.linuxPackages_latest.kernel.modDirVersion}/build
    echo "KERNEL_DIR set to $KERNEL_DIR"
  '';
}

