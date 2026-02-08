{
  description = "Nerd Fonts font-patcher";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      ...
    }:
    let
      # This version tracks the upstream ryanoasis/nerd-fonts release.
      version = "3.4.0";

      buildNerdFontPatcher =
        pkgs:
        pkgs.python3Packages.buildPythonApplication rec {
          pname = "nerd-font-patcher";
          inherit version;

          src = pkgs.fetchzip {
            url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v${version}/FontPatcher.zip";
            sha256 = "sha256-koZj0Tn1HtvvSbQGTc3RbXQdUU4qJwgClOVq1RXW6aM=";
            stripRoot = false;
          };

          propagatedBuildInputs = with pkgs.python3Packages; [ fontforge ];

          pyproject = false;

          patches = [
            ./patches/use-nix-paths.patch
            ./patches/horizontal-centered.patch
          ];

          dontBuild = true;

          installPhase = ''
            mkdir -p $out/bin $out/share $out/lib
            install -Dm755 font-patcher $out/bin/nerd-font-patcher
            cp -ra src/glyphs $out/share/
            cp -ra bin/scripts/name_parser $out/lib/
          '';

          meta = {
            description = "Nerd Fonts patcher - patches developer targeted fonts with glyphs";
            mainProgram = "nerd-font-patcher";
            homepage = "https://nerdfonts.com/";
            license = pkgs.lib.licenses.mit;
          };
        };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      flake = {
        # Expose the version so consumers can read it programmatically.
        lib.version = version;
      };
      systems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      perSystem =
        { pkgs, ... }:
        let
          nerd-font-patcher = buildNerdFontPatcher pkgs;
        in
        {
          packages = {
            default = nerd-font-patcher;
            nerd-font-patcher = nerd-font-patcher;
          };

          apps = {
            default = {
              type = "app";
              program = "${nerd-font-patcher}/bin/nerd-font-patcher";
            };
            nerd-font-patcher = {
              type = "app";
              program = "${nerd-font-patcher}/bin/nerd-font-patcher";
            };
          };
        };
    };
}
