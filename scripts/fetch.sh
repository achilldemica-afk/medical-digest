#!/bin/bash
# fetch.sh — PubMed E-utilities ile son 24 saatin abstractlarını çeker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Secrets yükle
source "$PROJECT_DIR/config/secrets.env"

JOURNALS_JSON="$PROJECT_DIR/config/journals.json"
OUTPUT_FILE="$PROJECT_DIR/data/raw_abstracts.txt"
EUTILS_BASE="https://eutils.ncbi.nlm.nih.gov/entrez/eutils"

# Gün bazlı reldate hesapla:
#   Pazartesi (1) → 3 gün (Cuma+haftasonu)
#   Cumartesi (6) → 2 gün (Perşembe+Cuma)
#   Pazar     (7) → 3 gün (Cuma+Cumartesi)
#   Diğer         → 1 gün
DOW=$(date +%u)  # 1=Pzt ... 7=Paz
case "$DOW" in
  1) RELDATE=3 ;;  # Pazartesi
  6) RELDATE=2 ;;  # Cumartesi
  7) RELDATE=3 ;;  # Pazar
  *) RELDATE=1 ;;
esac
echo "  Bugün DOW=$DOW, reldate=$RELDATE gün geriye bakılıyor." >&2
TMP_XML="/tmp/meddigest_fetch_$$.xml"
TMP_SEARCH="/tmp/meddigest_search_$$.json"
PYTHON="$PROJECT_DIR/.venv/bin/python3"

# Temizlik
cleanup() { rm -f "$TMP_XML" "$TMP_SEARCH"; }
trap cleanup EXIT

# Çıktı dosyasını sıfırla
> "$OUTPUT_FILE"

# journals.json'dan tüm ISSN + isim listesi
JOURNALS=$("$PYTHON" -c "
import json
with open('$JOURNALS_JSON') as f:
    journals = json.load(f)
for j in journals:
    print(j['issn'] + '|' + j['name'])
")

TOTAL_ARTICLES=0

while IFS='|' read -r ISSN JOURNAL_NAME; do
    echo "  → $JOURNAL_NAME ($ISSN) taranıyor..." >&2

    # esearch: son 24 saatteki makaleleri bul
    SEARCH_URL="${EUTILS_BASE}/esearch.fcgi?db=pubmed&term=${ISSN}%5BISSN%5D&reldate=${RELDATE}&datetype=edat&retmax=50&retmode=json&api_key=${NCBI_API_KEY}"

    if ! curl -sf --retry 3 --retry-delay 2 "$SEARCH_URL" -o "$TMP_SEARCH" 2>/dev/null; then
        echo "    Uyarı: esearch başarısız, atlanıyor." >&2
        sleep 0.15
        continue
    fi
    sleep 0.15

    PMIDS=$("$PYTHON" -c "
import json, sys
try:
    with open('$TMP_SEARCH') as f:
        data = json.load(f)
    ids = data.get('esearchresult', {}).get('idlist', [])
    print(','.join(ids))
except Exception as e:
    print('')
" 2>/dev/null)

    if [ -z "$PMIDS" ]; then
        continue
    fi

    PMID_COUNT=$(echo "$PMIDS" | tr ',' '\n' | grep -c '.' || true)
    echo "    $PMID_COUNT makale bulundu" >&2

    # efetch: XML olarak indir
    FETCH_URL="${EUTILS_BASE}/efetch.fcgi?db=pubmed&id=${PMIDS}&rettype=abstract&retmode=xml&api_key=${NCBI_API_KEY}"

    if ! curl -sf --retry 3 --retry-delay 2 "$FETCH_URL" -o "$TMP_XML" 2>/dev/null; then
        echo "    Uyarı: efetch başarısız, atlanıyor." >&2
        sleep 0.15
        continue
    fi
    sleep 0.15

    # XML parse et → raw_abstracts.txt formatına ekle
    JNAME="$JOURNAL_NAME"
    "$PYTHON" << PYEOF >> "$OUTPUT_FILE"
import xml.etree.ElementTree as ET
import re

try:
    root = ET.parse('$TMP_XML').getroot()
except ET.ParseError:
    import sys; sys.exit(0)

journal_name = """$JNAME"""

for article in root.findall('.//PubmedArticle'):
    try:
        title_el = article.find('.//ArticleTitle')
        title = ''.join(title_el.itertext()).strip() if title_el is not None else 'No title'
        title = re.sub(r'[\x00-\x1f]', ' ', title).strip()

        abstract_parts = article.findall('.//AbstractText')
        if not abstract_parts:
            continue
        abstract_text = ' '.join(''.join(p.itertext()).strip() for p in abstract_parts)
        abstract_text = re.sub(r'[\x00-\x1f]', ' ', abstract_text).strip()
        if len(abstract_text) < 50:
            continue

        authors = article.findall('.//Author')
        author_names = []
        for a in authors[:3]:
            ln = a.findtext('LastName', '')
            fn = a.findtext('ForeName', '')
            if ln:
                author_names.append(f"{ln} {fn}".strip())
        if len(authors) > 1:
            authors_str = author_names[0] + ' et al.' if author_names else 'Unknown'
        else:
            authors_str = author_names[0] if author_names else 'Unknown'

        pmid_el = article.find('.//PMID')
        pmid = pmid_el.text.strip() if pmid_el is not None else ''

        doi = ''
        for id_el in article.findall('.//ArticleId'):
            if id_el.get('IdType') == 'doi':
                doi = id_el.text.strip() if id_el.text else ''
                break

        pub_date = article.find('.//PubDate')
        date_str = ''
        if pub_date is not None:
            year = pub_date.findtext('Year', '')
            month = pub_date.findtext('Month', '')
            day = pub_date.findtext('Day', '')
            date_str = ' '.join(filter(None, [year, month, day]))

        url = f'https://doi.org/{doi}' if doi else (f'https://pubmed.ncbi.nlm.nih.gov/{pmid}/' if pmid else '')

        print('---')
        print(f'TITLE: {title}')
        print(f'JOURNAL: {journal_name}')
        print(f'AUTHORS: {authors_str}')
        print(f'DATE: {date_str}')
        print(f'PMID: {pmid}')
        print(f'DOI: {doi}')
        print(f'ABSTRACT: {abstract_text}')
        print(f'URL: {url}')
        print('---')
    except Exception:
        continue
PYEOF

    TOTAL_ARTICLES=$((TOTAL_ARTICLES + PMID_COUNT))

done <<< "$JOURNALS"

echo "Toplam $TOTAL_ARTICLES makale bulundu, $OUTPUT_FILE dosyasına yazıldı." >&2
