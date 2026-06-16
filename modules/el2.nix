{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware;
  tcblaunch = pkgs.requireFile {
    name = "tcblaunch.exe";
    sha256 = "sha256-RjUg4ZWB2pZINLTwexkwNmXccB3jHGrXSO+MvRMz5Ug=";
    message = ''
      tcblaunch.exe is required for EL2 boot support.

      Place tcblaunch.exe in the repository root and run:

        ./scripts/add-tcblaunch.sh
    '';
  };
  thinkpadT14sEnabled = cfg.lenovo-thinkpad-t14s.enable || cfg.lenovo-thinkpad-t14s-oled.enable;
  thinkpadT14sKernelParams = [
    "clk_ignore_unused"
    "pd_ignore_unused"
    "root=fstab"
    "cma=128M"
    "efi=noruntime"
    "id_aa64mmfr0.ecv=1"
    "iommu.strict=1"
    "mitigations=off"
    "crashkernel=2G-4G:320M,4G-32G:512M,32G-64G:1024M,64G-128G:2048M,128G-:4096M"
    "module_blacklist=algif_aead,esp4,esp6,rxrpc"
    "lsm=landlock,yama,bpf"
    "console=tty0"
  ];
in
{
  options.x1e.el2.enable = lib.mkEnableOption ''
    Enable the `el2` specialization and slbounce EFI driver. Needed to run
    virtual machines using KVM.
  '';

  options.x1e.el2.qebspilFirmwareFiles = lib.mkOption {
    type = with lib.types; listOf str;
    description = "List of firmware files to be loaded during boot, before switching to EL2";
  };

  config = lib.mkIf config.x1e.el2.enable {
    specialisation.el2.configuration = {
      system.nixos.tags = [ "el2" ];
      boot.loader.grub.configurationName = "NixOS EL2";
      hardware.deviceTree.name = lib.replaceString ".dtb" "-el2.dtb" config.hardware.deviceTree.name;
      boot.kernelParams = lib.mkIf thinkpadT14sEnabled (lib.mkOverride 10 thinkpadT14sKernelParams);
    };

    specialisation.oled-el1.configuration = lib.mkIf cfg.lenovo-thinkpad-t14s.enable {
      system.nixos.tags = [ "oled-el1" ];
      boot.loader.grub.configurationName = "NixOS OLED EL1";
      hardware.deviceTree.name = "qcom/x1e78100-lenovo-thinkpad-t14s-oled.dtb";
      boot.kernelParams = lib.mkOverride 10 thinkpadT14sKernelParams;
    };

    specialisation.oled-el2.configuration = lib.mkIf cfg.lenovo-thinkpad-t14s.enable {
      system.nixos.tags = [ "oled-el2" ];
      boot.loader.grub.configurationName = "NixOS OLED EL2";
      hardware.deviceTree.name = "qcom/x1e78100-lenovo-thinkpad-t14s-oled-el2.dtb";
      boot.kernelParams = lib.mkOverride 10 thinkpadT14sKernelParams;
    };

    # Firmware to load is retrieved by running
    # `find /sys/firmware/devicetree -name firmware-name -exec cat {} + | xargs -0n1`
    # as specified in the qebspil README.
    x1e.el2.qebspilFirmwareFiles = lib.mkMerge [
      (lib.mkIf cfg.lenovo-yoga-slim7x.enable [
        "qcom/x1e80100/LENOVO/83ED/qccdsp8380.mbn"
        "qcom/x1e80100/LENOVO/83ED/qcdxkmsuc8380.mbn"
        "qcom/x1e80100/LENOVO/83ED/qcvss8380.mbn"
        "qcom/x1e80100/LENOVO/83ED/qcadsp8380.mbn"
        "qcom/x1e80100/LENOVO/83ED/adsp_dtbs.elf"
        # Listed by retrieval command but not currently present in firmware files
        # "qcom/x1e80100/LENOVO/83ED/cdsp_dtbs.elf"
      ])
      (lib.mkIf thinkpadT14sEnabled [
        "qcom/x1e80100/LENOVO/21N1/qccdsp8380.mbn"
        "qcom/x1e80100/LENOVO/21N1/qcdxkmsuc8380.mbn"
        "qcom/x1e80100/LENOVO/21N1/qcvss8380.mbn"
        "qcom/x1e80100/LENOVO/21N1/qcadsp8380.mbn"
        "qcom/x1e80100/LENOVO/21N1/adsp_dtbs.elf"
        "qcom/x1e80100/LENOVO/21N1/cdsp_dtbs.elf"
      ])
    ];

    boot.loader.systemd-boot.extraFiles = {
      "EFI/systemd/drivers/slbounceaa64.efi" = "${pkgs.slbounce}/slbounce.efi";
      "EFI/systemd/drivers/tcblaunch.exe" = tcblaunch;
      "EFI/systemd/drivers/qebspilaa64.efi" = lib.mkIf (
        config.x1e.el2.qebspilFirmwareFiles != [ ]
      ) "${pkgs.qebspil}/qebspilaa64.efi";
    }
    // lib.listToAttrs (
      map (firmware: {
        name = "firmware/${firmware}";
        # Would be using config.hardware.firmware to avoid a redownload, but
        # that doesn't work if it's compressed.
        value = "${pkgs.linux-firmware}/lib/firmware/${firmware}";
      }) config.x1e.el2.qebspilFirmwareFiles
    );
  };
}
