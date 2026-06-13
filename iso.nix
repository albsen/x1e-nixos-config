{
  config,
  pkgs,
  lib,
  ...
}:

let
  tcblaunch = pkgs.requireFile {
    name = "tcblaunch.exe";
    sha256 = "sha256-RjUg4ZWB2pZINLTwexkwNmXccB3jHGrXSO+MvRMz5Ug=";
    message = ''
      tcblaunch.exe is required to build the EL2-capable ISO.

      Place tcblaunch.exe in the repository root and run:

        ./scripts/add-tcblaunch.sh
    '';
  };
in
{
  image.baseName =
    let
      deviceTreeBaseName = builtins.elemAt (lib.splitString "." (builtins.baseNameOf config.hardware.deviceTree.name)) 0;
    in
    lib.mkForce "nixos-${deviceTreeBaseName}";

  # Keep this within the short label limit exposed by some USB/firmware paths;
  # otherwise the initrd may search for the full label while the device appears
  # as a truncated label such as NIXOS-MINIM.
  isoImage.volumeID = lib.mkForce "NIXOS_X1E";

  boot.supportedFilesystems.zfs = lib.mkForce false;
  boot.supportedFilesystems.cifs = lib.mkForce false;

  hardware.enableAllHardware = lib.mkForce false;

  # For some reason the adsp booting up messes with USB boot, so disable it.
  boot.blacklistedKernelModules = [ "qcom_q6v5_pas" ];

  # Add this repo to the flake registry.
  nix.registry.x1e-nixos-config = {
    from = {
      type = "indirect";
      id = "x1e-nixos-config";
    };
    to = {
      type = "path";
      path = ./.;
    };
  };

  # Include this repo in the image
  systemd.tmpfiles.rules = [ "L /x1e-nixos-config - - - - ${./.}" ];

  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=512M
    RuntimeMaxUse=128M
  '';

  # Persist logs on the writable USB boot filesystem. Journald wants Unix
  # filesystem semantics, so keep the journals inside an ext4 image file rather
  # than writing them directly to the FAT boot partition.
  systemd.services.x1e-persistent-journal = {
    description = "Mount persistent journal storage on the USB boot media";
    wantedBy = [ "sysinit.target" ];
    wants = [ "iso.mount" ];
    after = [ "iso.mount" ];
    before = [ "systemd-journal-flush.service" ];
    path = [
      pkgs.coreutils
      pkgs.e2fsprogs
      pkgs.util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -u

      journalImage=/iso/nixos-logs/journal.ext4

      if ! mountpoint -q /iso; then
        echo "/iso is not mounted; persistent journal storage unavailable"
        exit 0
      fi

      if ! mkdir -p /iso/nixos-logs; then
        echo "/iso is not writable; persistent journal storage unavailable"
        exit 0
      fi

      if [ ! -f "$journalImage" ]; then
        tmpImage="$journalImage.tmp"
        rm -f "$tmpImage"
        truncate -s 512M "$tmpImage" || exit 0
        mkfs.ext4 -F -L X1E_JOURNAL "$tmpImage" || {
          rm -f "$tmpImage"
          exit 0
        }
        mv "$tmpImage" "$journalImage" || exit 0
      fi

      mkdir -p /var/log/journal
      if ! mountpoint -q /var/log/journal; then
        mount -o loop,rw "$journalImage" /var/log/journal || exit 0
      fi

      chown root:systemd-journal /var/log/journal || true
      chmod 2755 /var/log/journal || true
    '';
  };

  systemd.services.systemd-journal-flush = {
    wants = [ "x1e-persistent-journal.service" ];
    after = [ "x1e-persistent-journal.service" ];
  };

  # Some firmware/USB boot paths expose the labeled boot media as a vfat
  # partition rather than the iso9660 image. The initrd supports both.
  lib.isoFileSystems."/iso" = lib.mkImageMediaOverride {
    device =
      if config.boot.initrd.systemd.enable then
        "/dev/disk/by-label/${config.isoImage.volumeID}"
      else
        "/dev/root";
    fsType = "auto";
    neededForBoot = true;
    noCheck = true;
  };

  x1e.el2.enable = lib.mkDefault true;

  isoImage.contents = [
    {
      source = tcblaunch;
      target = "tcblaunch.exe";
    }
    {
      source = "${pkgs.slbounce}/slbounce.efi";
      target = "boot/slbounce.efi";
    }
  ];
}
