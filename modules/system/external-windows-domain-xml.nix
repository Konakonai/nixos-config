{
  domainName,
  uuid,
  memoryKiB,
  vcpus,
  diskById,
  ovmfCode,
  ovmfVars,
  guestToolsIso,
}:
''
  <domain type='kvm'>
    <name>${domainName}</name>
    <uuid>${uuid}</uuid>
    <metadata>
      <nixos:instance xmlns:nixos='https://nixos.org/virtualization'>
        <nixos:source>nixos-config</nixos:source>
      </nixos:instance>
    </metadata>
    <memory unit='KiB'>${toString memoryKiB}</memory>
    <currentMemory unit='KiB'>${toString memoryKiB}</currentMemory>
    <vcpu placement='static'>${toString vcpus}</vcpu>
    <resource>
      <partition>/machine</partition>
    </resource>
    <os>
      <type arch='x86_64' machine='q35'>hvm</type>
      <loader readonly='yes' secure='yes' type='pflash'>${ovmfCode}</loader>
      <nvram template='${ovmfVars}'/>
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
      </hyperv>
      <kvm>
        <hidden state='on'/>
      </kvm>
      <vmport state='off'/>
      <smm state='on'/>
    </features>
    <cpu mode='host-passthrough' check='none' migratable='off'>
      <topology sockets='1' dies='1' cores='${toString vcpus}' threads='1'/>
      <!-- Windows Hyper-V/WSL2 deadlocks during boot when nested VMX is exposed
           through this removable whole-disk guest. Native boots are unaffected. -->
      <feature policy='disable' name='vmx'/>
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
        <source dev='${diskById}'/>
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
''
