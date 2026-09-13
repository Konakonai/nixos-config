"""Own and restore the CPU overrides used by battery power-saver mode."""

import asyncio
import json
from pathlib import Path
import sys

CPU_ROOT = Path("/sys/devices/system/cpu")
TURBO = CPU_ROOT / "intel_pstate/no_turbo"
POLICY_ROOT = CPU_ROOT / "cpufreq"
SAVED = Path("/run/power-saver-cpu/previous.json")
MAX_FREQUENCY_KHZ = 1_800_000
UPOWER = "org.freedesktop.UPower"
PPD = "org.freedesktop.UPower.PowerProfiles"
SERVICES = {UPOWER: "/org/freedesktop/UPower", PPD: "/org/freedesktop/UPower/PowerProfiles"}


def read(path):
    return path.read_text().strip()


def write(path, value):
    path.write_text(f"{value}\n")


def policies(policy_root=POLICY_ROOT):
    return sorted(policy_root.glob("policy*"), key=lambda path: int(path.name.removeprefix("policy")))


def restore(turbo=TURBO, policy_root=POLICY_ROOT, saved=SAVED):
    if not saved.exists():
        return

    previous = json.loads(saved.read_text())
    if previous["turbo"] not in ("0", "1"):
        raise ValueError("Invalid saved turbo state")

    for name, limits in previous["policies"].items():
        policy = policy_root / name
        if not policy.is_dir():
            continue
        minimum, maximum = limits
        # Raise the ceiling first so restoring a higher minimum cannot fail.
        write(policy / "scaling_max_freq", maximum)
        write(policy / "scaling_min_freq", minimum)
    write(turbo, previous["turbo"])
    saved.unlink()
    print("Restored the previous CPU policy", flush=True)


def apply(on_battery, profile, turbo=TURBO, policy_root=POLICY_ROOT, saved=SAVED):
    if not (on_battery and profile == "power-saver"):
        restore(turbo, policy_root, saved)
        return

    current_policies = policies(policy_root)
    if not current_policies:
        raise FileNotFoundError("No CPU frequency policies found")

    if not saved.exists():
        previous = {
            "turbo": read(turbo),
            "policies": {
                policy.name: [
                    int(read(policy / "scaling_min_freq")),
                    int(read(policy / "scaling_max_freq")),
                ]
                for policy in current_policies
            },
        }
        if previous["turbo"] not in ("0", "1"):
            raise ValueError("Invalid current turbo state")
        temporary = saved.with_suffix(".tmp")
        temporary.write_text(json.dumps(previous, sort_keys=True) + "\n")
        temporary.replace(saved)

    try:
        write(turbo, 1)
        for policy in current_policies:
            hardware_minimum = int(read(policy / "cpuinfo_min_freq"))
            current_maximum = int(read(policy / "scaling_max_freq"))
            target_maximum = min(MAX_FREQUENCY_KHZ, current_maximum)
            write(policy / "scaling_min_freq", min(hardware_minimum, target_maximum))
            write(policy / "scaling_max_freq", target_maximum)
        print("Applied 400-1800 MHz CPU limit and disabled turbo", flush=True)
    except BaseException:
        restore(turbo, policy_root, saved)
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
    for rule in [
        "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'",
        "type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged'",
    ]:
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
