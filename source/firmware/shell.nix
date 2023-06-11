{ nixpkgs ? import <nixpkgs> {} }:

let cross-rv5 = import <nixpkgs> {
      crossSystem = {
        config = "riscv32-none-elf";
        gcc = { arch = "rv32i"; abi = "ilp32"; };
        libc = "newlib";
      };
    };
in
cross-rv5.mkShell {
  nativeBuildInputs = [ nixpkgs.gnumake nixpkgs.guile_3_0 ];
  shellHook = ''
    export NIX_SHELL_NAME="riscv"
  '';
}
