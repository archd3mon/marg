#!/usr/bin/env python3
"""
Prepares the deploy/hf_space directory for one-command deployment to Hugging Face Spaces (Docker SDK).

Usage:
    python scripts/prepare_hf_space.py
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
DEPLOY_DIR = ROOT_DIR / "deploy" / "hf_space"
BACKEND_APP = ROOT_DIR / "pump" / "backend" / "app"
BACKEND_REQ = ROOT_DIR / "pump" / "backend" / "requirements.txt"
DATA_DIR = ROOT_DIR / "pump" / "data"

DOCKERFILE_CONTENT = """FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \\
    DEBIAN_FRONTEND=noninteractive \\
    PORT=7860 \\
    PUMP_DATA_DIR=/app/data

# Install minimal OS dependencies for compiling C-extensions & SQLite
RUN apt-get update && apt-get install -y --no-install-recommends \\
    build-essential \\
    curl \\
    sqlite3 \\
    && rm -rf /var/lib/apt/lists/*

# Hugging Face Spaces runs as user 1000
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \\
    PATH=/home/user/.local/bin:$PATH

WORKDIR /app

# Copy requirements and install
COPY --chown=user:user requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir --upgrade pip && \\
    pip install --no-cache-dir -r requirements.txt

# Copy application code and dataset files
COPY --chown=user:user app /app/app
COPY --chown=user:user data /app/data

EXPOSE 7860

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "7860"]
"""

README_CONTENT = """---
title: Marg Pune Transit Backend
emoji: 🚌
colorFrom: blue
colorTo: indigo
sdk: docker
app_port: 7860
pinned: false
license: mit
---

# Marg — Pune Urban Mobility Planner (Backend)

High-performance transit routing, RAPTOR engine, and ML travel-time estimation API for Pune PMPML & Metro.

- **API Documentation (Swagger UI):** `/docs`
- **Health Check:** `/api/v1/health`
- **Root Status:** `/`
"""

GITATTRIBUTES_CONTENT = """data/gtfs/*.txt filter=lfs diff=lfs merge=lfs -text
*.gpickle filter=lfs diff=lfs merge=lfs -text
*.pkl filter=lfs diff=lfs merge=lfs -text
*.sqlite* filter=lfs diff=lfs merge=lfs -text
"""

GITIGNORE_CONTENT = """__pycache__/
*.py[cod]
.env
"""


def main():
    print(f"[*] Preparing Hugging Face deployment in: {DEPLOY_DIR}")

    if DEPLOY_DIR.exists():
        print(f"[-] Cleaning existing deployment folder...")
        # Preserve .git if it was already initialized
        git_dir = DEPLOY_DIR / ".git"
        temp_git = ROOT_DIR / "deploy" / ".git_temp"
        has_git = git_dir.exists()
        if has_git:
            if temp_git.exists():
                shutil.rmtree(temp_git)
            shutil.move(str(git_dir), str(temp_git))

        shutil.rmtree(DEPLOY_DIR)
        DEPLOY_DIR.mkdir(parents=True, exist_ok=True)

        if has_git:
            shutil.move(str(temp_git), str(DEPLOY_DIR / ".git"))
    else:
        DEPLOY_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Copy app
    print("  -> Copying pump/backend/app...")
    shutil.copytree(BACKEND_APP, DEPLOY_DIR / "app", ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))

    # 2. Copy requirements.txt
    print("  -> Copying requirements.txt...")
    shutil.copy(BACKEND_REQ, DEPLOY_DIR / "requirements.txt")

    # 3. Copy data
    print("  -> Copying pump/data (processed, models, gtfs)...")
    shutil.copytree(
        DATA_DIR,
        DEPLOY_DIR / "data",
        ignore=shutil.ignore_patterns("*.pyc", ".DS_Store", "pune_poi.sqlite-shm", "pune_poi.sqlite-wal")
    )

    # 4. Write Dockerfile
    print("  -> Writing Dockerfile (configured for Hugging Face Spaces port 7860)...")
    (DEPLOY_DIR / "Dockerfile").write_text(DOCKERFILE_CONTENT, encoding="utf-8")

    # 5. Write README.md with Hugging Face metadata
    print("  -> Writing README.md with HF metadata...")
    (DEPLOY_DIR / "README.md").write_text(README_CONTENT, encoding="utf-8")

    # 6. Write .gitattributes (Git LFS)
    print("  -> Writing .gitattributes for Git LFS tracking...")
    (DEPLOY_DIR / ".gitattributes").write_text(GITATTRIBUTES_CONTENT, encoding="utf-8")

    # 7. Write .gitignore
    (DEPLOY_DIR / ".gitignore").write_text(GITIGNORE_CONTENT, encoding="utf-8")

    # 8. Initialize git in deploy/hf_space if not yet initialized
    git_folder = DEPLOY_DIR / ".git"
    if not git_folder.exists():
        print("  -> Initializing git repository in deploy/hf_space...")
        subprocess.run(["git", "init", "-b", "main"], cwd=str(DEPLOY_DIR), check=True)
        subprocess.run(["git", "lfs", "install"], cwd=str(DEPLOY_DIR), check=True)

    print("\n[+] Hugging Face Spaces package ready in deploy/hf_space!")
    print("\nNext steps to deploy:")
    print("1. Create a new Space on https://huggingface.co/new-space")
    print("   - Space name: marg-backend")
    print("   - License: MIT")
    print("   - Select SDK: Docker (Blank)")
    print("   - Hardware: CPU basic - 2 vCPU - 16 GB - Free")
    print("\n2. In your terminal, run:")
    print("   cd deploy/hf_space")
    print("   git add .")
    print('   git commit -m "Deploy Marg backend to Hugging Face Spaces"')
    print("   git remote add space https://huggingface.co/spaces/<YOUR_HF_USERNAME>/<YOUR_SPACE_NAME>")
    print("   git push --force space main")
    print("\n3. Once deployed, your free HTTPS API URL will be:")
    print("   https://<YOUR_HF_USERNAME>-<YOUR_SPACE_NAME>.hf.space/api/v1")
    print("\n4. Run the Flutter app targeting your server:")
    print("   cd pump/mobile")
    print("   flutter run --dart-define=API_BASE=https://<YOUR_HF_USERNAME>-<YOUR_SPACE_NAME>.hf.space/api/v1")


if __name__ == "__main__":
    main()
