#!/usr/bin/env bash
# Crée dist/Sentier-<version>.zip à partager avec les amis.
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(sed -n 's/^## Version: //p' Sentier/Sentier.toc | tr -d '\r')
mkdir -p dist
rm -f "dist/Sentier-$version.zip"
zip -rq "dist/Sentier-$version.zip" Sentier -x '*.DS_Store'
echo "dist/Sentier-$version.zip"
