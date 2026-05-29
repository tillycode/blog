{
  pkgs ? import <nixpkgs> { },
}:
let
  # A dummy derivation to help nix-update. Run
  #
  #     nix-update -f shell.nix hugo-papermod --version branch
  #
  # to update the version.
  inherit (pkgs) lib;
  hugo-papermod = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "hugo-papermod";
    version = "8.0-unstable-2026-05-10";
    src = pkgs.fetchFromGitHub {
      owner = "adityatelange";
      repo = "hugo-PaperMod";
      rev = "154d006e0182dfc7da38008323976b02e6bfab4a";
      hash = "sha256-5g6qI2OxDd//bxIy9nQi9XSDMSgNGk+OLgT2EqIjGRY=";
    };
    patches = [
      ./patches/papermod-code-copy-button.patch
    ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r . $out/
      runHook postInstall
    '';
  });
  chroma-css =
    theme:
    pkgs.runCommand "chroma-${theme}.css" { } ''
      ${lib.getExe pkgs.hugo} gen chromastyles --style ${lib.escapeShellArg theme} > $out
    '';

  tomlFormat = pkgs.formats.toml { };
  yamlFormat = pkgs.formats.yaml { };

  treefmt-toml = tomlFormat.generate "treefmt.toml" {
    on-unmatched = "fatal";
    excludes = [
      ".gitignore"
      "*.patch"
    ];

    formatter.prettier = {
      command = lib.getExe pkgs.prettier;
      options = [
        "--write"
        "--config"
        prettier-config-yaml
      ];
      includes = [
        "*.md"
        "*.yaml"
        "*.html"
        "*.css"
      ];
    };

    formatter.nixfmt = {
      command = lib.getExe pkgs.nixfmt;
      includes = [ "*.nix" ];
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
  # based on https://github.com/hugomods/prettier-config/blob/154d006e0182dfc7da38008323976b02e6bfab4a/index.json
  prettier-config-yaml = yamlFormat.generate "prettierrc.yaml" {
    bracketSameLine = true;
    bracketSpacing = true;
    endOfLine = "lf";
    goTemplateBracketSpacing = true;
    singleQuote = true;
    tabWidth = 2;
    useTabs = false;
    overrides = [
      {
        files = [
          "*.html"
          "*.gotmpl"
          "*.tmpl.*"
        ];
        options = {
          parser = "go-template";
          bracketSameLine = true;
        };
      }
    ];
    plugins = [
      "${pkgs.prettier-plugin-go-template}/lib/node_modules/prettier-plugin-go-template/lib/index.js"
    ];
  };
in
pkgs.mkShellNoCC {
  packages = with pkgs; [
    (hugo.overrideAttrs (oldAttrs: {
      postPatch = (oldAttrs.postPatch or "") + ''
        go mod edit -replace github.com/alecthomas/chroma/v2=${
          # we assume the version of hugo and chroma in nixpkgs matches
          runCommand "chroma-source" { inherit (chroma) src; } ''
            mkdir -p "$out"
            cp -r --no-preserve=mode "$src/." "$out/"
            cd "$out"
            patch -p1 < ${./patches/chroma-bash-session-lexer.patch}
          ''
        }
      '';
    }))
    nix-update
    treefmt
    pre-commit
    rsync
  ];
  shellHook = ''
    ln -sfn ${hugo-papermod} themes/PaperMod
    ln -sfn ${treefmt-toml} .treefmt.toml
    ln -sfn ${pre-commit-config-yaml} .pre-commit-config.yaml
    ln -sfn ${prettier-config-yaml} .prettierrc.yaml
    ln -sfn ${chroma-css "github-dark"} assets/css/includes/chroma-styles.css
    ${lib.getExe pkgs.pre-commit} install
  '';
  passthru = {
    inherit hugo-papermod;
  };
}
