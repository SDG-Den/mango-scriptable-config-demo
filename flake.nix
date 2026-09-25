{
  description = "Scriptable mango compositor config demo (18 langs)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    mango.url = "github:SDG-Den/mango/config-scriptability";
  };

  outputs =
    {
      self,
      nixpkgs,
      mango,
    }:
    let
      systems = [
        "x86_64-linux"
      ];
      languages = [
        "python"
        "ruby"
        "node"
        "lua"
        "guile"
        "php"
        "janet"
        "r"
        "racket"
        "powershell"
        "bash"
        "zsh"
        "fish"
        "nushell"
        "chef"
        "cobol"
        "fortran"
        "emojicode"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          mangoPkg = mango.packages.${system}.default;
          libPkgs = builtins.listToAttrs (
            map (lang: {
              name = lang;
              value = pkgs.callPackage ./lib/${lang}/default.nix { };
            }) languages
          );
          demos = builtins.listToAttrs (
            map (lang: {
              name = lang;
              value = pkgs.callPackage ./demo/${lang}/default.nix {
                inherit mangoPkg;
                libPkg = libPkgs.${lang};
              };
            }) languages
          );
        in
        demos
        // {
          lib = libPkgs;
          default = demos.python;
        }
      );
    };
}
