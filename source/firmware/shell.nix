{ nixpkgs ? import <nixpkgs> {} }:

let cross-rv5 = import <nixpkgs> {
      crossSystem = {
        config = "riscv32-none-elf";
        gcc = { arch = "rv32i"; abi = "ilp32"; };
        libc = "newlib";
      };
    };
    flags-file = "compile_flags.txt";
in
cross-rv5.mkShell {
  nativeBuildInputs = [ nixpkgs.gnumake nixpkgs.guile_3_0 ];
  shellHook = ''
    export NIX_SHELL_NAME="riscv"
    echo | riscv32-none-elf-gcc -E -Wp,-v - 2>&1 | grep "^ .*newlib" | sed 's/^ /-I/' > ${flags-file}
  '';
}
