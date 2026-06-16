{
  config,
  pkgs,
  lib,
  ...
}:

let
  sshAuthorizedKeysPath = "/iso/ssh/authorized_keys";
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

  environment.systemPackages = with pkgs; [
    aider-chat
    codex
    cryptsetup
    dosfstools
    efibootmgr
    e2fsprogs
    git
    gptfdisk
    htop
    jq
    lsof
    neovim
    networkmanager
    nvme-cli
    parted
    pciutils
    ripgrep
    rsync
    strace
    tcpdump
    usbutils
    vim
  ];

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  systemd.services.x1e-usb-authorized-keys = {
    description = "Import SSH authorized keys from the USB boot media";
    wantedBy = [ "multi-user.target" ];
    before = [ "sshd.service" ];
    after = [ "sysroot-iso.mount" "iso.mount" ];
    requires = [ "iso.mount" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 0700 /root/.ssh

      if [ -s ${sshAuthorizedKeysPath} ]; then
        install -m 0600 /dev/null /root/.ssh/authorized_keys
        ${pkgs.gnugrep}/bin/grep -E '^[[:space:]]*(ssh-|ecdsa-|sk-ssh-|sk-ecdsa-)' ${sshAuthorizedKeysPath} \
          > /root/.ssh/authorized_keys || true
      else
        echo "No SSH authorized keys found at ${sshAuthorizedKeysPath}"
      fi
    '';
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
    {
      source = pkgs.writeText "x1e-authorized-keys-placeholder" ''
        # Add public SSH keys here, one per line.
        # The live ISO imports this file into /root/.ssh/authorized_keys at boot.
      '';
      target = "ssh/authorized_keys";
    }
  ];
}
