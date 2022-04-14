{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    nixpkgs-fmt
    rnix-lsp

    curl
    jq
    wireguard-tools
  ];
}
