#!/usr/bin/env bash
set -euo pipefail

# Configuration - adjust if needed
TARGET_REPO="https://github.com/sheddy-cloud/backend.git"
SOURCE_AI="https://github.com/sheddy-cloud/backend-ai.git"
SOURCE_NAPASA="https://github.com/sheddy-cloud/backend-napasa.git"
WORKDIR="${HOME}/repo-merge-work"
AI_TEMP="${WORKDIR}/backend-ai-temp"
NAPASA_TEMP="${WORKDIR}/backend-napasa-temp"
COMBINED="${WORKDIR}/combined"

mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

# Ensure git-filter-repo is available
if ! command -v git-filter-repo >/dev/null 2>&1; then
  echo "git-filter-repo not found; attempting to install via pip3"
  if command -v pip3 >/dev/null 2>&1; then
    pip3 install --user git-filter-repo
    export PATH="$HOME/.local/bin:$PATH"
  else
    echo "pip3 not found. Please install git-filter-repo (pip3 install git-filter-repo) and re-run."
    exit 1
  fi
fi

# 1) Rewrite backend-ai/main into ai-backend/ and push as ai-backend-main
rm -rf "${AI_TEMP}"
git clone "${SOURCE_AI}" "${AI_TEMP}"
cd "${AI_TEMP}"
git checkout main
git remote remove origin || true
git filter-repo --refs refs/heads/main --to-subdirectory-filter ai-backend
# Push to target as a temporary branch
git remote add target "${TARGET_REPO}"
# Use GITHUB_TOKEN if provided in environment; otherwise rely on your auth
if [ -n "${GITHUB_TOKEN-}" ]; then
  git push "https://x-access-token:${GITHUB_TOKEN}@github.com/sheddy-cloud/backend.git" refs/heads/main:refs/heads/ai-backend-main --force
else
  git push target refs/heads/main:refs/heads/ai-backend-main --force
fi
cd "${WORKDIR}"

# 2) Rewrite backend-napasa/main into main-backend/ and push as main-backend-main
rm -rf "${NAPASA_TEMP}"
git clone "${SOURCE_NAPASA}" "${NAPASA_TEMP}"
cd "${NAPASA_TEMP}"
git checkout main
git remote remove origin || true
git filter-repo --refs refs/heads/main --to-subdirectory-filter main-backend
git remote add target "${TARGET_REPO}"
if [ -n "${GITHUB_TOKEN-}" ]; then
  git push "https://x-access-token:${GITHUB_TOKEN}@github.com/sheddy-cloud/backend.git" refs/heads/main:refs/heads/main-backend-main --force
else
  git push target refs/heads/main:refs/heads/main-backend-main --force
fi
cd "${WORKDIR}"

# 3) Merge those branches into the target main
rm -rf "${COMBINED}"
git clone "${TARGET_REPO}" "${COMBINED}"
cd "${COMBINED}"
git checkout main
git fetch origin ai-backend-main:ai-backend-main || git fetch origin refs/heads/ai-backend-main:refs/heads/ai-backend-main
git fetch origin main-backend-main:main-backend-main || git fetch origin refs/heads/main-backend-main:refs/heads/main-backend-main
# Merge branches
git merge --allow-unrelated-histories ai-backend-main --no-edit || true
git merge --allow-unrelated-histories main-backend-main --no-edit || true
# Push combined main
if [ -n "${GITHUB_TOKEN-}" ]; then
  git push "https://x-access-token:${GITHUB_TOKEN}@github.com/sheddy-cloud/backend.git" main
else
  git push origin main
fi

# Optional: remove the temporary remote branches on origin
git push origin --delete ai-backend-main || true
git push origin --delete main-backend-main || true

echo "Merge finished. Combined repo main branch should contain ai-backend/ and main-backend/."