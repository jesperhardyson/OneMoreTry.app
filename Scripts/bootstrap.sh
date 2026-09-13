#!/usr/bin/env bash
# Generates OneMoreTry.xcodeproj from project.yml.
#
# The project file is not committed: project.pbxproj produces a merge conflict
# in every pull request that touches a file, which is exactly what a PR-based
# workflow cannot absorb. Run this after cloning and after adding files to App/.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen not found. Install it with: brew install xcodegen" >&2
    exit 1
fi

xcodegen generate --quiet
echo "Generated OneMoreTry.xcodeproj from project.yml"
