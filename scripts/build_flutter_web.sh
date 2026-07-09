#!/usr/bin/env bash
set -e

FLUTTER_DIR="$HOME/flutter"

if [ ! -d "$FLUTTER_DIR/bin" ]; then
  echo "==> Installation Flutter stable..."
  git clone https://github.com/flutter/flutter.git --depth 1 --branch stable "$FLUTTER_DIR"
fi

export PATH="$PATH:$FLUTTER_DIR/bin"

flutter config --no-analytics
flutter config --enable-web

echo "==> Flutter version :"
flutter --version

cd cityflow_app
flutter pub get
flutter build web --release --base-href /
echo "==> Build terminé : cityflow_app/build/web"
