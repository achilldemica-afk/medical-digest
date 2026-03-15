#!/bin/bash
# curate.sh — Claude Code CLI ile abstract kürasyon
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PYTHON="$PROJECT_DIR/.venv/bin/python3"

PROMPT_FILE="$PROJECT_DIR/config/curator_prompt.txt"
INPUT_FILE="$PROJECT_DIR/data/raw_abstracts.txt"
OUTPUT_FILE="$PROJECT_DIR/data/curated.json"
CLAUDE_BIN="/usr/local/bin/claude"

# Ham veri var mı kontrol et
if [ ! -s "$INPUT_FILE" ]; then
    echo "Uyarı: raw_abstracts.txt boş, kürasyon atlanıyor." >&2
    echo "[]" > "$OUTPUT_FILE"
    exit 0
fi

echo "  Kürasyon başlıyor ($(wc -l < "$INPUT_FILE") satır)..." >&2

# claude -p ile kürasyon
"$CLAUDE_BIN" -p "$(cat "$PROMPT_FILE")" \
    --model claude-opus-4-6 \
    < "$INPUT_FILE" > "$OUTPUT_FILE.tmp"

# JSON başında/sonunda olası markdown code fences temizle
"$PYTHON" -c "
import sys, re
content = open('$OUTPUT_FILE.tmp').read().strip()
match = re.search(r'^\`\`\`(?:json)?\s*([\s\S]*?)\`\`\`\s*$', content)
if match:
    content = match.group(1).strip()
if not content.startswith('['):
    content = '[]'
print(content)
" > "$OUTPUT_FILE"

rm -f "$OUTPUT_FILE.tmp"

# Validate JSON
if ! "$PYTHON" -c "import json; json.load(open('$OUTPUT_FILE'))" 2>/dev/null; then
    echo "Uyarı: Geçersiz JSON, boş array yazılıyor." >&2
    echo "[]" > "$OUTPUT_FILE"
fi

COUNT=$("$PYTHON" -c "import json; print(len(json.load(open('$OUTPUT_FILE'))))" 2>/dev/null || echo 0)
echo "  Kürasyon tamamlandı: $COUNT makale seçildi." >&2
