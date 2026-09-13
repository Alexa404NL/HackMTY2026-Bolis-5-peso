#!/usr/bin/env bash
# Build de Flutter web en Vercel (Root Directory: banorte_app). Uso: vercel-build.sh install|build
set -euo pipefail

FLUTTER_VERSION=3.47.4
FLUTTER=.flutter/bin/flutter

case "${1:-}" in
  install)
    [ -d .flutter ] || git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git .flutter
    "$FLUTTER" config --enable-web --no-analytics
    "$FLUTTER" pub get
    ;;
  build)
    : "${BACKEND_URL:?Configura BACKEND_URL en Vercel con la URL del backend en Render}"
    "$FLUTTER" build web --release --dart-define=BACKEND_URL="$BACKEND_URL"
    ;;
  *)
    echo "uso: vercel-build.sh install|build" >&2
    exit 1
    ;;
esac
