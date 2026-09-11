"""Own only the battery/power-saver turbo override; leave other knobs alone."""

import asyncio
from pathlib import Path
import sys

KNOB = Path("/sys/devices/system/cpu/intel_pstate/no_turbo")
SAVED = Path("/run/power-saver-turbo/previous")
UPOWER = "org.freedesktop.UPower"
PPD = "org.freedesktop.UPower.PowerProfiles"
SERVICES = {UPOWER: "/org/freedesktop/UPower", PPD: "/org/freedesktop/UPower/PowerProfiles"}


def restore(knob=KNOB, saved=SAVED):
    if saved.exists():
        previous = saved.read_text().strip()
        if previous not in ("0", "1"):
            raise ValueError("Invalid saved turbo state")
        knob.write_text(previous + "\n")
        saved.unlink()
        print("Restored no_turbo=" + previous, flush=True)


def apply(on_battery, profile, knob=KNOB, saved=SAVED):
    if on_battery and profile == "power-saver":
        if not saved.exists():
            previous = knob.read_text().strip()
            if previous not in ("0", "1"):
                raise ValueError("Invalid current turbo state")
            # Save before writing so ExecStopPost can recover even after a crash.
            temporary = saved.with_suffix(".tmp")
            temporary.write_text(previous + "\n")
            temporary.replace(saved)
        if knob.read_text().strip() != "1":
            knob.write_text("1\n")
            print("Disabled turbo for battery power-saver", flush=True)
    else:
        restore(knob, saved)


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
            if {"OnBattery", "ActiveProfile"}.intersection(message.body[1]) or {"OnBattery", "ActiveProfile"}.intersection(message.body[2]):
                changed.set()
        elif message.interface == "org.freedesktop.DBus" and message.member == "NameOwnerChanged":
            if message.body[0] in SERVICES:
                changed.set()

    bus.add_message_handler(event)
    for rule in [
        "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'",
        "type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged'",
    ]:
        await call(Message(destination="org.freedesktop.DBus", path="/org/freedesktop/DBus",
                           interface="org.freedesktop.DBus", member="AddMatch", signature="s", body=[rule]))

    async def get(service, prop):
        reply = await call(Message(destination=service, path=SERVICES[service],
                                   interface="org.freedesktop.DBus.Properties", member="Get",
                                   signature="ss", body=[service, prop]))
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
        raise SystemExit("usage: power-saver-turbo.py [--restore]")
