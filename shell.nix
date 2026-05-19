{
  pkgs ? import <nixpkgs> { },
}:
let
  # A dummy derivation to help nix-update. Run
  #
  #     nix-update -f shell.nix hugo-papermod
  #
  # to update the version.
  inherit (pkgs) lib;
  hugo-papermod = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "hugo-papermod";
    version = "8.0";
    src = pkgs.fetchFromGitHub {
      owner = "adityatelange";
      repo = "hugo-PaperMod";
      rev = finalAttrs.version;
      hash = "sha256-5g6qI2OxDd//bxIy9nQi9XSDMSgNGk+OLgT2EqIjGRY=";
    };
  });

  tomlFormat = pkgs.formats.toml { };
  yamlFormat = pkgs.formats.yaml { };
  treefmt-toml = tomlFormat.generate "treefmt.toml" {
    on-unmatched = "fatal";
    excludes = [ ".gitignore" ];

    formatter.prettier = {
      command = lib.getExe pkgs.prettier;
      includes = [ "*.md" ];
    };

    formatter.nixfmt = {
      command = lib.getExe pkgs.nixfmt;
      includes = [ "*.nix" ];
    };

    formatter.taplo = {
      command = lib.getExe pkgs.taplo;
      includes = [ "*.toml" ];
      options = [ "format" ];
    };

    formatter.shfmt = {
      command = lib.getExe pkgs.shfmt;
      includes = [ ".envrc" ];
      options = [
        "-w"
        "-i"
        "2"
        "-s"
      ];
    };
  };
  pre-commit-config-yaml = yamlFormat.generate "pre-commit-config.yaml" {
    repos = [
      {
        repo = "local";
        hooks = [
          {
            id = "treefmt";
            name = "treefmt";
            entry = "${lib.getExe pkgs.treefmt} --fail-on-change --no-cache";
            language = "system";
            types = [ "file" ];
            pass_filenames = true;
          }
        ];
      }
    ];
  };
in
pkgs.mkShellNoCC {
  packages = with pkgs; [
    hugo
    nix-update
    treefmt
    pre-commit
  ];
  shellHook = ''
    ln -sf ${hugo-papermod.src} themes/PaperMod
    ln -sf ${treefmt-toml} .treefmt.toml
    ln -sf ${pre-commit-config-yaml} .pre-commit-config.yaml
    ${lib.getExe pkgs.pre-commit} install
  '';
  passthru = {
    inherit hugo-papermod;
  };
}
