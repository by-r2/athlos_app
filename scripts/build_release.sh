#!/usr/bin/env bash
# Build release with Supabase dart-defines.
# Usage: ./scripts/build_release.sh [appbundle|ipa]
# Requires .env (shared) + .env.prod (hosted Supabase).

set -e
cd "$(dirname "$0")/.."

set -a
[ -f .env ] && source .env
[ -f .env.prod ] && source .env.prod
set +a

if [ -z "${SUPABASE_URL}" ] || [ -z "${SUPABASE_ANON_KEY}" ]; then
  echo "Error: SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env.prod"
  echo "See .env.example"
  exit 1
fi

TARGET="${1:-appbundle}"
DEFINES="--dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"

case "$TARGET" in
  appbundle)
    flutter build appbundle --release $DEFINES
    echo "AAB: build/app/outputs/bundle/release/app-release.aab"
    ;;
  ipa)
    flutter build ipa $DEFINES
    echo "IPA: build/ios/ipa/"
    ;;
  *)
    echo "Usage: $0 [appbundle|ipa]"
    exit 1
    ;;
esac
