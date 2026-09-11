{ hostProfile, lib, pkgs, ... }:

let
  cfg = hostProfile.virtualization.externalWindows or { enable = false; };
  domainName = cfg.domainName;
  memoryKiB = cfg.memoryGiB * 1024 * 1024;
  ovmf = pkgs.OVMFFull.fd;

  guestToolsPowerShell = pkgs.writeText "Install-Guest-Tools.ps1" ''
    #Requires -RunAsAdministrator
    $ErrorActionPreference = "Stop"

    function Install-Driver {
        param([string]$Path)
        Write-Host "Installing driver: $Path" -ForegroundColor Cyan
        & pnputil.exe /add-driver $Path /install
        if ($LASTEXITCODE -notin @(0, 3010)) {
            throw "pnputil failed for $Path with exit code $LASTEXITCODE"
        }
    }

    Install-Driver (Join-Path $PSScriptRoot "amd64\vioserial\vioser.inf")
    Install-Driver (Join-Path $PSScriptRoot "amd64\qxl\qxldod.inf")

    $installDir = Join-Path $env:ProgramFiles "SPICE Guest Tools"
    $existingService = Get-Service -Name "vdservice" -ErrorAction SilentlyContinue
    if ($existingService) {
        Stop-Service -Name "vdservice" -Force -ErrorAction SilentlyContinue
    }

    New-Item -ItemType Directory -Force -Path $installDir | Out-Null
    Copy-Item -Force (Join-Path $PSScriptRoot "amd64\vdagent\*") $installDir

    if (-not $existingService) {
        & (Join-Path $installDir "vdservice.exe") install
        if ($LASTEXITCODE -ne 0) {
            throw "SPICE guest agent service installation failed with exit code $LASTEXITCODE"
        }
    }

    Start-Service -Name "vdservice"
    Write-Host ""
    Write-Host "SPICE display driver and guest agent installed." -ForegroundColor Green
    Write-Host "Restart Windows, then resize or maximize the VM window."
  '';

  guestToolsCmd = pkgs.writeText "Install-Guest-Tools.cmd" ''
    @echo off
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Guest-Tools.ps1"
    echo.
    pause
  '';

  guestToolsReadme = pkgs.writeText "README.txt" ''
    Run Install-Guest-Tools.cmd as Administrator inside Windows.

    It installs the QXL display driver, VirtIO serial driver and SPICE guest
    agent needed for dynamic resolution, clipboard integration and smoother
    windowed display.
  '';

  guestToolsIso = pkgs.runCommand "external-windows-guest-tools.iso" {
    nativeBuildInputs = [ pkgs.xorriso ];
  } ''
    iso_root="$TMPDIR/iso-root"
    mkdir -p "$iso_root/amd64"
    cp -R ${pkgs.win-spice}/amd64/qxl "$iso_root/amd64/"
    cp -R ${pkgs.win-spice}/amd64/vdagent "$iso_root/amd64/"
    cp -R ${pkgs.win-spice}/amd64/vioserial "$iso_root/amd64/"
    cp ${guestToolsPowerShell} "$iso_root/Install-Guest-Tools.ps1"
    cp ${guestToolsCmd} "$iso_root/Install-Guest-Tools.cmd"
    cp ${guestToolsReadme} "$iso_root/README.txt"

    xorriso -as mkisofs \
      -iso-level 3 \
      -J \
      -joliet-long \
      -R \
      -V SPICE_TOOLS \
      -o "$out" \
      "$iso_root"
  '';

  domainXml = pkgs.writeText "${domainName}.xml" (import ./external-windows-domain-xml.nix {
    inherit domainName memoryKiB guestToolsIso;
    uuid = cfg.uuid;
    vcpus = cfg.vcpus;
    diskById = cfg.diskById;
    ovmfCode = "${ovmf}/FV/OVMF_CODE.fd";
    ovmfVars = "${ovmf}/FV/OVMF_VARS.ms.fd";
  });

  launcher = pkgs.writeShellApplication {
    name = "external-windows";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      jq
      libnotify
      libvirt
      util-linux
      udisks
      virt-viewer
      zenity
    ];
    text = ''
      export EXTERNAL_WINDOWS_DOMAIN=${lib.escapeShellArg domainName}
      export EXTERNAL_WINDOWS_DISK=${lib.escapeShellArg cfg.diskById}
      export EXTERNAL_WINDOWS_CONNECTION=qemu:///system
    '' + builtins.readFile ../../scripts/external-windows.sh;
  };

  desktopItem = pkgs.makeDesktopItem {
    name = "external-windows-11";
    desktopName = "External Windows 11";
    genericName = "Virtual Machine";
    comment = "Safely unmount and start the aigo U397 Windows installation";
    exec = "${lib.getExe launcher}";
    icon = "computer";
    categories = [
      "System"
      "Emulator"
    ];
    terminal = false;
    startupNotify = true;
  };
in
lib.mkIf (cfg.enable or false) {
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true;
    };
  };

  virtualisation.spiceUSBRedirection.enable = true;
  programs.virt-manager.enable = true;
  security.polkit.enable = true;

  users.users.${hostProfile.user.userName}.extraGroups = [ "libvirtd" ];

  # Grant only libvirt's unprivileged QEMU account access to this exact USB
  # disk. The serial match applies to the disk and its partitions.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="${cfg.diskSerial}", GROUP="qemu-libvirtd", MODE="0660"
  '';

  environment.systemPackages = [
    desktopItem
    launcher
    pkgs.virt-viewer
  ];

  # Keep the domain definition reproducible while leaving runtime state
  # (NVRAM and TPM data) under libvirt's normal persistent state directories.
  systemd.services.external-windows-libvirt-domain = {
    description = "Define the external Windows 11 libvirt domain";
    wantedBy = [ "multi-user.target" ];
    requires = [
      "external-windows-device-permissions.service"
      "libvirtd.service"
    ];
    after = [
      "external-windows-device-permissions.service"
      "libvirtd.service"
      "systemd-udev-settle.service"
    ];
    restartTriggers = [ domainXml ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.libvirt}/bin/virsh --connect qemu:///system define ${domainXml}
    '';
  };

  # A live switch reloads udev rules but does not reliably retrigger the parent
  # whole-disk node. Apply the exact serial-scoped rule immediately so QEMU can
  # open the disk without waiting for a replug or reboot.
  systemd.services.external-windows-device-permissions = {
    description = "Apply permissions for the external Windows disk";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udevd.service" ];
    before = [ "external-windows-libvirt-domain.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.systemd}/bin/udevadm trigger \
        --action=change \
        --subsystem-match=block \
        --property-match=ID_SERIAL_SHORT=${lib.escapeShellArg cfg.diskSerial} \
        --settle
    '';
  };
}
