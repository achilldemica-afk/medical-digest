#!/Users/barisyurtsever/medical-digest/.venv/bin/python3
"""build.py — curated.json'dan statik HTML üretir."""

import json
import os
import sys
from datetime import datetime
from pathlib import Path
from jinja2 import Environment, BaseLoader

PROJECT_DIR = Path(__file__).parent.parent
DATA_DIR = PROJECT_DIR / "data"
DOCS_DIR = PROJECT_DIR / "docs"
CONFIG_FILE = PROJECT_DIR / "config" / "site_config.json"

DOCS_DIR.mkdir(exist_ok=True)
(DOCS_DIR / "archive").mkdir(exist_ok=True)

# Config yükle
with open(CONFIG_FILE) as f:
    site_config = json.load(f)

# Curated data yükle
curated_file = DATA_DIR / "curated.json"
articles = []
if curated_file.exists():
    try:
        with open(curated_file) as f:
            articles = json.load(f)
    except (json.JSONDecodeError, ValueError):
        articles = []

today = datetime.now().strftime("%Y-%m-%d")
today_formatted = datetime.now().strftime("%-d %B %Y")

CATEGORY_LABELS = {
    "paradigma-kırıcı": "Paradigma Kırıcı",
    "disiplinler-arası": "Disiplinler Arası",
    "yeni-çerçeve": "Yeni Çerçeve",
    "metodolojik-inovasyon": "Metodolojik İnovasyon",
    "beklenmedik-bulgu": "Beklenmedik Bulgu",
}

# ── HTML TEMPLATES ─────────────────────────────────────────────────────────

BASE_HTML = """\
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{{ page_title }} — {{ site.title }}</title>
<link rel="stylesheet" href="{{ css_path }}">
</head>
<body>
<header>
  <div class="header-inner">
    <a href="{{ root_path }}index.html" class="site-name">{{ site.title }}</a>
    <span class="site-subtitle">{{ site.subtitle }}</span>
  </div>
</header>
<main>
{% block content %}{% endblock %}
</main>
<footer>
  <a href="{{ root_path }}archive/index.html">Arşiv</a>
  &nbsp;·&nbsp;
  <a href="https://github.com/{{ site.github_repo }}" target="_blank" rel="noopener">GitHub</a>
</footer>
</body>
</html>
"""

INDEX_CONTENT = """\
{% extends "base" %}
{% block content %}
<div class="digest-header">
  <h1>Günün Digest'i</h1>
  <time datetime="{{ today }}">{{ today_formatted }}</time>
</div>

{% if articles %}
<div class="article-count">{{ articles|length }} makale seçildi</div>
<div class="cards">
{% for a in articles %}
<article class="card">
  <div class="card-meta">
    <span class="journal">{{ a.journal }}</span>
    <span class="badge badge-{{ a.category | replace(' ', '-') }}">{{ category_labels.get(a.category, a.category) }}</span>
  </div>
  <h2 class="card-title">
    {% if a.url %}<a href="{{ a.url }}" target="_blank" rel="noopener">{{ a.title }}</a>{% else %}{{ a.title }}{% endif %}
  </h2>
  <p class="card-authors">{{ a.authors }}</p>
  <div class="summary">
    <p>{{ a.summary }}</p>
  </div>
  <div class="why-interesting">
    <strong>Neden ilginç?</strong>
    <p>{{ a.why_interesting }}</p>
  </div>
</article>
{% endfor %}
</div>
{% else %}
<div class="empty-state">
  <p>Bugün dikkat çekici bir şey bulunamadı.</p>
  <p class="empty-sub">Seçim kriteri yüksek tutuldu — yarın tekrar kontrol edin.</p>
</div>
{% endif %}
{% endblock %}
"""

ARCHIVE_INDEX_CONTENT = """\
{% extends "base" %}
{% block content %}
<div class="digest-header">
  <h1>Arşiv</h1>
</div>
{% if archive_dates %}
<ul class="archive-list">
{% for item in archive_dates %}
<li>
  <a href="{{ item.file }}">{{ item.label }}</a>
</li>
{% endfor %}
</ul>
{% else %}
<p>Henüz arşiv yok.</p>
{% endif %}
{% endblock %}
"""

DAILY_ARCHIVE_CONTENT = INDEX_CONTENT


class InheritanceLoader(BaseLoader):
    def __init__(self, templates):
        self.templates = templates

    def get_source(self, environment, template):
        if template in self.templates:
            src = self.templates[template]
            return src, None, lambda: True
        raise Exception(f"Template not found: {template}")


templates = {
    "base": BASE_HTML,
    "index": INDEX_CONTENT,
    "archive_index": ARCHIVE_INDEX_CONTENT,
    "daily": DAILY_ARCHIVE_CONTENT,
}

env = Environment(loader=InheritanceLoader(templates))
env.globals["site"] = site_config
env.globals["category_labels"] = CATEGORY_LABELS


def render(template_name, **ctx):
    tmpl = env.get_template(template_name)
    return tmpl.render(**ctx)


# ── 1. index.html ──────────────────────────────────────────────────────────

index_html = render(
    "index",
    page_title="Bugün",
    css_path="style.css",
    root_path="",
    today=today,
    today_formatted=today_formatted,
    articles=articles,
)
(DOCS_DIR / "index.html").write_text(index_html, encoding="utf-8")

# ── 2. Günlük arşiv sayfası ────────────────────────────────────────────────

daily_html = render(
    "daily",
    page_title=today_formatted,
    css_path="../style.css",
    root_path="../",
    today=today,
    today_formatted=today_formatted,
    articles=articles,
)
(DOCS_DIR / "archive" / f"{today}.html").write_text(daily_html, encoding="utf-8")

# ── 3. archive/index.html ──────────────────────────────────────────────────

archive_files = sorted(
    (DOCS_DIR / "archive").glob("[0-9][0-9][0-9][0-9]-*.html"),
    reverse=True,
)
archive_dates = []
for f in archive_files:
    date_str = f.stem  # e.g. 2026-03-15
    try:
        dt = datetime.strptime(date_str, "%Y-%m-%d")
        label = dt.strftime("%-d %B %Y")
    except ValueError:
        label = date_str
    archive_dates.append({"file": f.name, "label": label})

archive_index_html = render(
    "archive_index",
    page_title="Arşiv",
    css_path="../style.css",
    root_path="../",
    archive_dates=archive_dates,
)
(DOCS_DIR / "archive" / "index.html").write_text(archive_index_html, encoding="utf-8")

print(f"Build tamamlandı: {today}, {len(articles)} makale, {len(archive_dates)} arşiv sayfası.")
