#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

swift format lint --recursive --parallel --strict Sources Tests Scripts Package.swift
swift package plugin --allow-writing-to-package-directory swiftlint --strict
