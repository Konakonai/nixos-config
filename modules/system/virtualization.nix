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

  domainXml = pkgs.writeText "${domainName}.xml" ''
    <domain type='kvm'>
      <name>${domainName}</name>
      <uuid>${cfg.uuid}</uuid>
      <metadata>
        <nixos:instance xmlns:nixos='https://nixos.org/virtualization'>
          <nixos:source>nixos-config</nixos:source>
        </nixos:instance>
      </metadata>
      <memory unit='KiB'>${toString memoryKiB}</memory>
      <currentMemory unit='KiB'>${toString memoryKiB}</currentMemory>
      <vcpu placement='static'>${toString cfg.vcpus}</vcpu>
      <resource>
        <partition>/machine</partition>
      </resource>
      <os>
        <type arch='x86_64' machine='q35'>hvm</type>
        <loader readonly='yes' secure='yes' type='pflash'>${ovmf}/FV/OVMF_CODE.fd</loader>
        <nvram template='${ovmf}/FV/OVMF_VARS.ms.fd'/>
        <bootmenu enable='yes' timeout='3000'/>
      </os>
      <features>
        <acpi/>
        <apic/>
        <hyperv mode='custom'>
          <relaxed state='on'/>
          <vapic state='on'/>
          <spinlocks state='on' retries='8191'/>
          <vpindex state='on'/>
          <runtime state='on'/>
          <synic state='on'/>
          <stimer state='on'>
            <direct state='on'/>
          </stimer>
          <reset state='on'/>
          <frequencies state='on'/>
          <tlbflush state='on'/>
          <ipi state='on'/>
          <evmcs state='on'/>
        </hyperv>
        <kvm>
          <hidden state='on'/>
        </kvm>
        <vmport state='off'/>
        <smm state='on'/>
      </features>
      <cpu mode='host-passthrough' check='none' migratable='off'>
        <topology sockets='1' dies='1' cores='4' threads='2'/>
        <feature policy='require' name='vmx'/>
      </cpu>
      <clock offset='localtime'>
        <timer name='rtc' tickpolicy='catchup'/>
        <timer name='pit' tickpolicy='delay'/>
        <timer name='hpet' present='no'/>
        <timer name='hypervclock' present='yes'/>
      </clock>
      <on_poweroff>destroy</on_poweroff>
      <on_reboot>restart</on_reboot>
      <on_crash>restart</on_crash>
      <pm>
        <suspend-to-mem enabled='no'/>
        <suspend-to-disk enabled='no'/>
      </pm>
      <devices>
        <emulator>/run/libvirt/nix-emulators/qemu-system-x86_64</emulator>
        <disk type='block' device='disk'>
          <driver name='qemu' type='raw' cache='none' io='native'/>
          <source dev='${cfg.diskById}'/>
          <target dev='sda' bus='sata'/>
          <serial>AIGO-U397-WINDOWS</serial>
          <boot order='1'/>
        </disk>
        <disk type='file' device='cdrom'>
          <driver name='qemu' type='raw'/>
          <source file='${guestToolsIso}'/>
          <target dev='sdb' bus='sata'/>
          <readonly/>
        </disk>
        <controller type='pci' model='pcie-root'/>
        <controller type='sata' index='0'/>
        <controller type='usb' index='0' model='qemu-xhci' ports='15'/>
        <controller type='virtio-serial' index='0'/>
        <interface type='user'>
          <model type='e1000e'/>
        </interface>
        <serial type='pty'>
          <target type='isa-serial' port='0'/>
        </serial>
        <console type='pty'>
          <target type='serial' port='0'/>
        </console>
        <channel type='spicevmc'>
          <target type='virtio' name='com.redhat.spice.0'/>
        </channel>
        <input type='tablet' bus='usb'/>
        <input type='keyboard' bus='usb'/>
        <graphics type='spice' autoport='yes'>
          <listen type='none'/>
          <image compression='auto_glz'/>
        </graphics>
        <sound model='ich9'/>
        <audio id='1' type='spice'/>
        <video>
          <model type='qxl' ram='131072' vram='131072' vgamem='65536'
                 heads='1' primary='yes'/>
        </video>
        <redirdev bus='usb' type='spicevmc'/>
        <redirdev bus='usb' type='spicevmc'/>
        <tpm model='tpm-crb'>
          <backend type='emulator' version='2.0'/>
        </tpm>
        <watchdog model='itco' action='reset'/>
        <memballoon model='none'/>
      </devices>
    </domain>
  '';

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
      domain=${lib.escapeShellArg domainName}
      disk=${lib.escapeShellArg cfg.diskById}
      connection=qemu:///system

      fail() {
        notify-send --urgency=critical "External Windows" "$1" || true
        zenity --error --title="External Windows" --text="$1" || true
        exit 1
      }

      if [[ ! -b "$disk" ]]; then
        fail "The aigo U397 Windows disk is not connected."
      fi

      if ! virsh --connect "$connection" list --name |
        grep --fixed-strings --line-regexp --quiet "$domain"
      then
        mapfile -t mounted_devices < <(
          lsblk --json --paths --output NAME,MOUNTPOINTS "$disk" |
            jq -r '
              .blockdevices[]
              | recurse(.children[]?)
              | select(any(.mountpoints[]?; . != null))
              | .name
            '
        )

        for device in "''${mounted_devices[@]}"; do
          udisksctl unmount --block-device "$device" ||
            fail "Could not unmount $device. Close files using the Windows disk and retry."
        done

        if lsblk --json --paths --output MOUNTPOINTS "$disk" |
          jq -e 'any(.blockdevices[] | recurse(.children[]?); any(.mountpoints[]?; . != null))' \
            >/dev/null
        then
          fail "A Windows disk partition is still mounted. The VM was not started."
        fi

        virsh --connect "$connection" start "$domain" ||
          fail "libvirt could not start $domain. Open Virtual Machine Manager for details."
      fi

      exec virt-viewer --connect "$connection" --wait --reconnect "$domain"
    '';
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
