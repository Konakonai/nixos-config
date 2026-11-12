"""Own and restore the turbo and PCIe overrides used by battery power-saver mode."""

import asyncio
import json
from pathlib import Path
import re
import sys

CPU_ROOT = Path("/sys/devices/system/cpu")
TURBO = CPU_ROOT / "intel_pstate/no_turbo"
SAVED = Path("/run/power-saver-cpu/previous.json")
PCIE_ASPM = Path("/sys/module/pcie_aspm/parameters/policy")
UPOWER = "org.freedesktop.UPower"
PPD = "org.freedesktop.UPower.PowerProfiles"
SERVICES = {UPOWER: "/org/freedesktop/UPower", PPD: "/org/freedesktop/UPower/PowerProfiles"}


def read(path):
    return path.read_text().strip()


def write(path, value):
    path.write_text(f"{value}\n")


def selected_choice(path):
    value = read(path)
    match = re.search(r"\[([^]]+)]", value)
    return match.group(1) if match else value


def match_rules():
    # Scoped to the two services. An unfiltered PropertiesChanged match woke
    # this process for every property change on the system bus.
    rules = []
    for name, path in SERVICES.items():
        rules.append(
            "type='signal',interface='org.freedesktop.DBus.Properties',"
            f"member='PropertiesChanged',path='{path}'"
        )
        rules.append(
            "type='signal',interface='org.freedesktop.DBus',"
            f"member='NameOwnerChanged',arg0='{name}'"
        )
    return rules


def restore(turbo=TURBO, saved=SAVED, pcie_aspm=PCIE_ASPM):
    if not saved.exists():
        return

    previous = json.loads(saved.read_text())
    if previous["turbo"] not in ("0", "1"):
        raise ValueError("Invalid saved turbo state")

    write(turbo, previous["turbo"])
    if previous.get("pcie_aspm") is not None and pcie_aspm.exists():
        write(pcie_aspm, previous["pcie_aspm"])
    saved.unlink()
    print("Restored the previous turbo and PCIe policy", flush=True)


def apply(
    on_battery,
    profile,
    turbo=TURBO,
    saved=SAVED,
    pcie_aspm=PCIE_ASPM,
):
    if not (on_battery and profile == "power-saver"):
        restore(turbo, saved, pcie_aspm)
        return

    if not saved.exists():
        previous = {
            "turbo": read(turbo),
            "pcie_aspm": selected_choice(pcie_aspm) if pcie_aspm.exists() else None,
        }
        if previous["turbo"] not in ("0", "1"):
            raise ValueError("Invalid current turbo state")
        temporary = saved.with_suffix(".tmp")
        temporary.write_text(json.dumps(previous, sort_keys=True) + "\n")
        temporary.replace(saved)

    # No frequency cap: battery history showed the 1.8 GHz limit saved nothing
    # at idle, where the draw is set by package idle depth, while it slowed
    # every burst. Turbo stays off because it caps the cost of sustained load.
    try:
        write(turbo, 1)
        if pcie_aspm.exists():
            write(pcie_aspm, "powersupersave")
        print("Disabled turbo and enabled PCIe power saving", flush=True)
    except BaseException:
        restore(turbo, saved, pcie_aspm)
        raise


async def main():
    from dbus_next import BusType, Message, MessageType
    from dbus_next.aio import MessageBus

    bus = await MessageBus(bus_type=BusType.SYSTEM).connect()
    changed = asyncio.Event()

    async def call(message):
        reply = await bus.call(message)
        if reply.message_type == MessageType.ERROR:
            raise RuntimeError(f"D-Bus error: {reply.error_name}")
        return reply

    def event(message):
        if message.message_type != MessageType.SIGNAL:
            return
        if message.interface == "org.freedesktop.DBus.Properties" and message.path in SERVICES.values():
            if {"OnBattery", "ActiveProfile"}.intersection(message.body[1]) or {
                "OnBattery", "ActiveProfile"
            }.intersection(message.body[2]):
                changed.set()
        elif message.interface == "org.freedesktop.DBus" and message.member == "NameOwnerChanged":
            if message.body[0] in SERVICES:
                changed.set()

    bus.add_message_handler(event)
    for rule in match_rules():
        await call(
            Message(
                destination="org.freedesktop.DBus",
                path="/org/freedesktop/DBus",
                interface="org.freedesktop.DBus",
                member="AddMatch",
                signature="s",
                body=[rule],
            )
        )

    async def get(service, prop):
        reply = await call(
            Message(
                destination=service,
                path=SERVICES[service],
                interface="org.freedesktop.DBus.Properties",
                member="Get",
                signature="ss",
                body=[service, prop],
            )
        )
        return reply.body[0].value

    async def reconcile():
        changed.set()
        while True:
            await changed.wait()
            changed.clear()
            apply(await get(UPOWER, "OnBattery"), await get(PPD, "ActiveProfile"))

    tasks = [asyncio.create_task(reconcile()), asyncio.create_task(bus.wait_for_disconnect())]
    done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
    for task in pending:
        task.cancel()
    for task in done:
        task.result()
    raise ConnectionError("System bus disconnected")


if __name__ == "__main__":
    if sys.argv[1:] == ["--restore"]:
        restore()
    elif not sys.argv[1:]:
        asyncio.run(main())
    else:
        raise SystemExit("usage: power-saver-cpu.py [--restore]")
