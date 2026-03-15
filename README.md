# Medical Digest

Kişisel günlük tıp araştırma bülteni. Her sabah 07:00'de PubMed'den 20 derginin yeni yayınlarını tarar, Claude (Opus 4.6) ile önemli makaleleri kürate eder ve GitHub Pages'e deploy eder.

**Site:** https://achilldemica-afk.github.io/medical-digest

## Pipeline

```
launchd 07:00
  → scripts/fetch.sh     # PubMed E-utilities
  → scripts/curate.sh    # claude -p (Claude Code CLI)
  → scripts/build.py     # Jinja2 → HTML
  → scripts/deploy.sh    # git push → GitHub Pages
```

## Manuel Çalıştırma

```bash
./scripts/run_digest.sh
```

## Kurulum

```bash
pip3 install jinja2
cp com.barish.meddigest.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.barish.meddigest.plist
```
