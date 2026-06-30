#!/usr/bin/env python3
import json
import subprocess
import sys


def simctl_json(*arguments: str) -> dict:
    return json.loads(subprocess.check_output(["xcrun", "simctl", "list", *arguments, "--json"]))


def version_tuple(runtime: dict) -> tuple[int, ...]:
    return tuple(
        int(part)
        for part in str(runtime.get("version", "0")).split(".")
        if part.isdigit()
    )


runtimes = simctl_json("runtimes").get("runtimes", [])
ios_runtimes = [
    runtime
    for runtime in runtimes
    if runtime.get("isAvailable", False)
    and (
        runtime.get("platform") == "iOS"
        or runtime.get("identifier", "").startswith("com.apple.CoreSimulator.SimRuntime.iOS")
    )
]
if not ios_runtimes:
    sys.exit("No available iOS Simulator runtimes found.")

device_types = simctl_json("devicetypes").get("devicetypes", [])
iphone_types = [
    device_type
    for device_type in device_types
    if device_type.get("identifier") and device_type.get("name", "").startswith("iPhone")
]
if not iphone_types:
    sys.exit("No iPhone Simulator device types found.")

selected_runtime = max(ios_runtimes, key=version_tuple)
preferred_names = ["iPhone 17", "iPhone 17 Pro", "iPhone 16", "iPhone 16 Pro", "iPhone 15"]
selected_device = next(
    (
        device_type
        for name in preferred_names
        for device_type in iphone_types
        if device_type.get("name") == name
    ),
    iphone_types[-1],
)

simulator_udid = subprocess.check_output(
    [
        "xcrun",
        "simctl",
        "create",
        "CI iPhone",
        selected_device["identifier"],
        selected_runtime["identifier"],
    ],
    text=True,
).strip()

print(f"platform=iOS Simulator,id={simulator_udid}")
