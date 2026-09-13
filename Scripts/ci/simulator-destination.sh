#!/usr/bin/env bash
# Prints an xcodebuild -destination string for an available iOS simulator.
#
# Naming a device literally ("platform=iOS Simulator,name=iPhone 17") breaks in two ways on
# CI: it fails at random on runners whose CoreSimulator has not registered its device set
# yet, and it pins the build to a model name Apple retires without notice. Resolving a UDID
# at run time avoids both.
#
# The choice is deterministic — newest runtime at or above the deployment target, then the
# first device name in sort order — so two runs on the same image pick the same simulator.
set -euo pipefail

# Must track the iOS deploymentTarget in project.yml. A runtime below it cannot install the
# app, and xcodebuild reports that as a confusing signing failure rather than a clear one.
MIN_IOS="${MIN_IOS:-26.0}"

xcrun simctl list devices available --json | MIN_IOS="$MIN_IOS" python3 -c '
import json, os, sys

raw = os.environ["MIN_IOS"]
minimum = tuple(int(part) for part in raw.split("."))
devices = json.load(sys.stdin)["devices"]

candidates = []
for runtime, entries in devices.items():
    name = runtime.rsplit(".", 1)[-1]          # com.apple...SimRuntime.iOS-26-4 -> iOS-26-4
    if not name.startswith("iOS-"):
        continue
    version = tuple(int(part) for part in name[len("iOS-"):].split("-"))
    if version < minimum:
        continue
    for entry in entries:
        candidates.append((version, entry["name"], entry["udid"]))

if not candidates:
    sys.exit("no available iOS simulator at or above iOS " + raw)

# project.yml sets TARGETED_DEVICE_FAMILY to iPhone only, so prefer one. An iPhone app
# does build against an iPad destination, but the warnings it produces are noise that
# hides real ones.
phones = [c for c in candidates if c[1].startswith("iPhone")] or candidates

newest = max(version for version, _, _ in phones)
name, udid = sorted((n, u) for version, n, u in phones if version == newest)[0]

readable = ".".join(str(part) for part in newest)
print("Selected " + name + " on iOS " + readable, file=sys.stderr)
print("platform=iOS Simulator,id=" + udid)
'
