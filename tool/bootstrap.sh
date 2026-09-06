#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v flutter >/dev/null 2>&1; then
  echo 'Install the Flutter stable SDK and add flutter to PATH first: https://docs.flutter.dev/install' >&2
  exit 1
fi
# Flutter generates platform wrappers and may add a template widget test.
# Preserve this project's tests and pubspec around generation.
backup_dir=$(mktemp -d)
trap 'rm -rf "$backup_dir"' EXIT
cp pubspec.yaml "$backup_dir/pubspec.yaml"
cp -R test "$backup_dir/test"
cp -R lib "$backup_dir/lib"
flutter create --platforms=android,ios,web --project-name one_touch_striker --org com.zaefrul --no-pub .
cp "$backup_dir/pubspec.yaml" pubspec.yaml
cp -R "$backup_dir/lib/." lib/
cp "$backup_dir/test/"*.dart test/
flutter pub get
dart format lib test
flutter analyze
flutter test
printf '\nReady. Connect a device and run: flutter run\n'
