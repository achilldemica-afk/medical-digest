#!/bin/bash
# run_digest.sh — Ana orchestrator: fetch → curate → build → deploy
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG="$HOME/Library/Logs/meddigest.log"

# PATH genişlet (launchd ortamı kısıtlı olabilir)
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" | tee -a "$LOG"
}

log "=== Medical Digest başlatılıyor ==="

log "Fetch başlıyor..."
if bash "$SCRIPT_DIR/fetch.sh" 2>> "$LOG"; then
    log "Fetch tamamlandı."
else
    log "HATA: Fetch başarısız, önceki digest korunuyor."
    exit 0
fi

log "Kürasyon başlıyor..."
if bash "$SCRIPT_DIR/curate.sh" 2>> "$LOG"; then
    log "Kürasyon tamamlandı."
else
    log "HATA: Kürasyon başarısız."
    echo "[]" > "$PROJECT_DIR/data/curated.json"
fi

log "HTML build başlıyor..."
if python3 "$SCRIPT_DIR/build.py" 2>> "$LOG"; then
    log "Build tamamlandı."
else
    log "HATA: Build başarısız."
    exit 1
fi

log "Deploy başlıyor..."
if bash "$SCRIPT_DIR/deploy.sh" 2>> "$LOG"; then
    log "Deploy tamamlandı."
else
    log "HATA: Deploy başarısız."
    exit 1
fi

log "=== Tamamlandı. ==="
