#!/bin/bash
# deploy.sh — docs/ ve curated.json'ı git push ile GitHub Pages'e gönderir
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

TODAY=$(date +%Y-%m-%d)

git add docs/ data/curated.json
git diff --cached --quiet && { echo "Deploy: değişiklik yok, atlanıyor." >&2; exit 0; }
git commit -m "Digest $TODAY"
git push origin main

echo "Deploy tamamlandı: $TODAY" >&2
