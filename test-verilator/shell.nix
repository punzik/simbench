{ pkgs ? import <nixpkgs> {} }:

with pkgs;
let
  flags-file = "compile_flags.txt";
in
mkShell {
  packages = [ gnumake verilator ];

  shellHook = ''
    echo -n                                      > ${flags-file}
    echo -DVM_TRACE=1                           >> ${flags-file}
    echo -xc++                                  >> ${flags-file}
    echo -I./testbench                          >> ${flags-file}
    echo -I${verilator}/share/verilator/include >> ${flags-file}
    echo -I${clang}/resource-root/include       >> ${flags-file}
    echo -I${glibc.dev}/include                 >> ${flags-file}
  '';
}
