{ pkgs ? import <nixpkgs> {} }:

with pkgs;
mkShell { packages = [ gnumake zlib /* haskellPackages.sv2v */ ]; }
