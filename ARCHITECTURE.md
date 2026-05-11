# Architecture & Code Explained

---

## Table of Contents

1. [How the App Works](#how-the-app-works)
2. [Code Structure](#code-structure)
3. [Docker](#docker)
4. [GCP Infrastructure](#gcp-infrastructure)
5. [Request Flow (end-to-end)](#request-flow-end-to-end)

---

## How the App Works

User registers/logs in → pastes a long URL → gets a short URL → shares it → anyone who visits the short URL gets redirected (via 4s interstitial) → clicks are recorded with timestamp, IP, referrer → owner sees analytics on dashboard.

---

## Code Structure

### `app/__init__.py` — App Factory

Creates the Flask app, initialises extensions, registers blueprints, runs `db.create_all()` — tables created automatically on every startup in both dev and prod.

```
db (SQLAlchemy)  ─┐
migrate           ├─ attached to app in create_app()
login_manager    ─┘

Blueprints registered:
  auth_bp       → /login, /register, /logout
  urls_bp       → /, /shorten, /<code>, /api/urls/<id>
  analytics_bp  → /dashboard, /api/stats/<code>
  qr_bp         → /qr/<code>
```

### `app/models.py` — Database Models

Three tables:

```
users ──< urls ──< clicks
```

| Model | Key fields |
|-------|-----------|
| `User` | `username`, `email`, `password_hash` |
| `URL` | `short_code`, `custom_slug`, `original_url`, `expires_at`, `is_active` |
| `Click` | `url_id`, `timestamp`, `ip_address`, `referrer` |

`URL.generate_short_code()` — loops generating random 6-char codes until one isn't taken.  
`URL.total_clicks` — SQL `COUNT` query, not in-memory list.  
`URL.is_expired` — compares `expires_at` against current UTC time.

### `app/auth.py` — Authentication

- Passwords hashed with `bcrypt` (salted, never stored plain)
- Login checks email → then bcrypt compare
- `?next=` redirect validated to relative paths only (blocks open redirect)

### `app/urls.py` — Core URL Logic

- `POST /shorten` — validates URL, optional custom slug, optional expiry, saves to DB
- `GET /<code>` — looks up by `short_code` OR `custom_slug`, records click, renders interstitial
- Expiry datetime: browser sends local time + `tz_offset` (minutes per `getTimezoneOffset()`), server converts to UTC before storing
- `DELETE /api/urls/<id>` — soft delete (`is_active = False`), not hard delete

### `app/analytics.py` — Stats

- `GET /dashboard` — all active URLs for logged-in user
- `GET /api/stats/<code>` — returns JSON: total clicks, daily clicks (last 7 days), top 5 referrers

### `app/qr.py` — QR Codes

Generates QR PNG on-the-fly pointing to the short URL. Uses `qrcode` library, returns `image/png`. No auth required — QR codes are public (same as visiting the short URL).

### `app/templates/` — Jinja2 Templates

| Template | Route |
|----------|-------|
| `base.html` | Base layout — nav, dark mode toggle, flash messages |
| `index.html` | Home page — URL shorten form |
| `dashboard.html` | User's links with analytics charts |
| `redirect.html` | 4s interstitial countdown before redirect |
| `login.html` | Login form |
| `register.html` | Registration form |
| `_qr_modal.html` | QR code popup modal (included in dashboard) |
| `404.html` | Not found error page |
| `410.html` | Gone (expired/deleted link) error page |

### `app/static/` — Static Assets

- `input.css` — Tailwind CSS source file with custom directives
- `output.css` — compiled + minified CSS (gitignored, built by Docker or `npm run build:css`)

### `run.py` — Entry Point

Dev server only. Gunicorn imports `app` object directly — `run.py` is not executed in production.

### `config.py` — Configuration

Reads `.env` via `python-dotenv`. Constructs `DATABASE_URL` automatically:

```
DATABASE_URL set?    →  use it directly (TCP URL for GCP, any URL for custom)
GCP_PROJECT_ID set?  →  constructs Cloud SQL socket URL (legacy fallback)
Neither              →  sqlite:///urlshortener.db  (local dev)
```

In production, always set `DATABASE_URL` explicitly as a TCP URL:
`postgresql://user:pass@CLOUD_SQL_IP/dbname`

Refuses to start in production if `SECRET_KEY` is still the default dev value.

### `requirements.txt` — Python Dependencies

All versions pinned (e.g. `flask==3.1.3`) for reproducible builds. Key packages:

| Package | Purpose |
|---------|---------|
| `flask` | Web framework |
| `flask-sqlalchemy` | ORM |
| `flask-login` | Session-based auth |
| `flask-migrate` | Alembic DB migrations |
| `bcrypt` | Password hashing |
| `psycopg2-binary` | PostgreSQL driver |
| `qrcode[pil]` | QR code generation |
| `gunicorn` | Production WSGI server |
| `python-dotenv` | Load `.env` file |

### `package.json` — Node Scripts

Node is only used to run Tailwind CSS CLI — not part of the runtime.

| Script | Command |
|--------|---------|
| `build:css` | Compile + minify Tailwind once |
| `watch:css` | Watch mode — recompile on template changes |

### `.env.example` — Environment Template

Copy to `.env` and fill in values. Never committed — `.gitignore` excludes `.env`.

| Variable | Purpose |
|----------|---------|
| `SECRET_KEY` | Flask session signing key |
| `BASE_URL` | Public URL of app (used in QR codes + short URLs) |
| `DATABASE_URL` | Full PostgreSQL TCP URL (set after Cloud SQL setup) |
| `DB_NAME`, `DB_USER`, `DB_PASS` | DB credentials (used by setup script) |
| `GCP_PROJECT_ID` | GCP project (used by all `gcp/*.ps1` scripts) |
| `GCP_REGION`, `GCP_ZONE` | Deployment region/zone |

### `Dockerfile` — Container Build

See [Docker](#docker) section below.

### `.gitignore`

Excludes: `.env`, `venv/`, `node_modules/`, `instance/` (SQLite), `app/static/output.css`, `__pycache__/`.

---

## Docker

### Why Docker?

GCP Compute Engine VMs run the app as a container — Docker packages the app + all dependencies into one portable image. No "works on my machine" issues.

### Dockerfile (multi-stage build)

```dockerfile
# Stage 1 — Node (CSS only)
FROM node:20-slim AS css-builder
# Installs Tailwind, compiles input.css → output.css (minified)
# Node is NOT included in the final image

# Stage 2 — Python (production image)
FROM python:3.12-slim
# Installs Python deps, copies app code + compiled CSS from stage 1
# Runs: gunicorn -w 4 -b 0.0.0.0:8080 run:app
```

**Why multi-stage?** Node.js is ~200MB and only needed to compile CSS. Final image is Python-only (~150MB) — smaller = faster pulls on every VM boot.

**gunicorn** — production WSGI server. `-w 4` = 4 worker processes handling requests concurrently. Flask's built-in dev server is single-threaded and not safe for production.

### Image naming convention

```
{REGION}-docker.pkg.dev/{PROJECT_ID}/url-shortener/app:{tag}
e.g. us-central1-docker.pkg.dev/my-proj/url-shortener/app:latest
                                                              :a3f9c12  ← git SHA tag
```

Both `latest` and a git SHA tag are pushed — `latest` is used by VMs, SHA tags enable rollback.

---

## GCP Infrastructure

```
Internet
    │
    ▼
Forwarding Rule (external IP, port 80)
    │
    ▼
Target HTTP Proxy
    │
    ▼
URL Map
    │
    ▼
Backend Service  ←── Health Check (/health, port 8080)
    │
    ▼
Managed Instance Group (MIG)
    ├── VM 1: Container (Docker image from Artifact Registry)
    └── VM 2: Container (Docker image from Artifact Registry)
              │
              ▼
         Cloud SQL (PostgreSQL, TCP public IP)
```

### Components

**Artifact Registry** — GCP's private Docker registry. Images pushed here before VMs pull them.

**Instance Template** — blueprint for VMs: machine type (`e2-micro`), Docker image to run, env vars (`DATABASE_URL`, `SECRET_KEY`, etc.), network tags.

**Managed Instance Group (MIG)** — runs N identical VMs from the template. Handles:
- Auto-healing: replaces crashed VMs automatically
- Autoscaling: 2–5 VMs based on CPU (scales up at 60% utilization)
- Rolling updates: replaces VMs one at a time during deploys (zero downtime)

**Load Balancer** — GCP's global HTTP load balancer. Distributes traffic across MIG VMs. Health check polls `/health` every few seconds — unhealthy VMs are removed from rotation.

**Cloud SQL** — managed PostgreSQL. VMs connect via TCP to the public IP — authorized networks set to `0.0.0.0/0` so VMs can reach it. `DATABASE_URL` is passed as an env var in the instance template.

### GCP Scripts

| Script | What it does |
|--------|-------------|
| `cloud-sql-setup.ps1` | Creates PostgreSQL instance (public IP, authorized networks), database, user — prints `DATABASE_URL` |
| `push-image.ps1` | Builds Docker image, pushes to Artifact Registry (tagged `latest` + git SHA) |
| `instance-template.ps1` | Creates instance template + MIG + autoscaling + firewall rule |
| `load-balancer.ps1` | Creates health check, backend service, URL map, proxy, forwarding rule |
| `teardown.ps1` | Deletes everything in reverse order |

All scripts read from `.env` — no values are hardcoded in the scripts.

---

## Request Flow (end-to-end)

### Shortening a URL

```
Browser  →  POST /shorten
         →  urls.py validates URL + slug + expiry
         →  URL row inserted into Cloud SQL
         →  returns short URL to user
```

### Visiting a short URL

```
Browser  →  GET /<code>
         →  urls.py queries DB for short_code OR custom_slug
         →  checks is_active + is_expired
         →  Click row inserted (ip, user_agent, referrer)
         →  renders redirect.html (4s countdown → JS redirect)
         →  browser navigates to original_url
```

### Viewing analytics

```
Browser  →  GET /api/stats/<code>
         →  analytics.py verifies url belongs to current_user
         →  SQL COUNT for total clicks
         →  GROUP BY date for last 7 days
         →  GROUP BY referrer for top 5
         →  returns JSON → rendered as chart in dashboard
```
