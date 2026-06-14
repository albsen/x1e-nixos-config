{
  fetchFromGitHub,
  linuxManualConfig,
  linuxPackagesFor,
  ...
}:

linuxPackagesFor (linuxManualConfig {
  src = fetchFromGitHub {
    owner = "steev";
    repo = "linux";
    rev = "eb3faf6d54cf6abecc346996afbc912fd4126962";
    hash = "sha256-WHEmUzzOlOi+Hi2oLUrmYxuFe3r2jNMo3/cwIXCafU8=";
  };
  version = "7.0.12";
  kernelPatches = import ../kernel-patches/lenovo-t14s-linux-7.0.y/series.nix;
  configfile = ../working_el2.config;
})
