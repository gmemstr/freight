{
  binaryen,
  callPackage,
  fetchFromGitHub,
  wasm-pack,
  craneLib,
  ...
}: args: let
  wasm-bindgen-cli = (callPackage ./wasm-bindgen.nix {}) args;

  # https://github.com/cloudflare/workers-rs/blob/fea2e8e14d8807d422bde6bfab837914a0019e8d/worker-build/src/main.rs#L19-L24
  wasmImport = builtins.readFile ./snippets/import.js;

  # https://github.com/cloudflare/workers-rs/blob/fea2e8e14d8807d422bde6bfab837914a0019e8d/worker-build/src/main.rs#L26-L32
  wasmImportReplacement = builtins.readFile ./snippets/importReplacement.js;

  filteredArgs = builtins.removeAttrs args [
    "craneLib"
  ];
in
  (args.craneLib or craneLib).mkCargoDerivation (filteredArgs
    // {
      # Make sure that build succeeds even if user didn't provide cargoArtifacts value
      cargoArtifacts = args.cargoArtifacts or null;

      nativeBuildInputs =
        (args.nativeBuildInputs or [])
        ++ [
          wasm-bindgen-cli
          wasm-pack
          binaryen
        ];

      buildPhaseCargoCommand =
        args.buildPhaseCargoCommand
        or ''
          HOME=$(mktemp -d)
          mkdir -p $out

          wasm-pack build ${if args.workspace then args.pname else "./"} \
            --no-typescript \
            --target bundler \
            --out-dir $out/build \
            --out-name index \
            --release

          substituteInPlace $out/build/index_bg.js \
            --replace "${wasmImport}" "${wasmImportReplacement}"
        '';

      doInstallCargoArtifacts = args.doInstallCargoArtifacts or false;

      installPhaseCommand =
        args.installPhaseCommand
        or ''
          mkdir -p $out

          mv $out/build/index_bg.js $out
          mv $out/build/index_bg.wasm $out/index.wasm
          rm -r $out/build

          [ -f build/snippets ] && mv $out/build/snippets $out
        '';
    })
