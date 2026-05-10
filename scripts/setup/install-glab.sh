#!/usr/bin/env bash
set -euo pipefail

# install-glab.sh — Install GitLab CLI (glab)
# Detects OS and installs via appropriate package manager

echo "=== Installing GitLab CLI (glab) ==="

# Detect OS
case "$(uname -s)" in
  Linux*)
    if command -v apt-get &> /dev/null; then
      # Debian/Ubuntu
      echo "Installing via apt..."
      curl -fsSL https://raw.githubusercontent.com/uDonate/homebrew-glab/main/install.sh | sudo bash
      # Alternative: snap
      # sudo snap install glab
    elif command -v brew &> /dev/null; then
      echo "Installing via Homebrew..."
      brew install glab
    else
      echo "Installing from binary..."
      VERSION=$(curl -s https://gitlab.com/api/v4/projects/34675721/releases | grep -oP '"tag_name":"\Kv[^"]+' | head -1)
      curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/${VERSION}/downloads/glab_${VERSION#v}_Linux_x86_64.tar.gz" | tar xz
      sudo mv glab /usr/local/bin/
    fi
    ;;
  Darwin*)
    if command -v brew &> /dev/null; then
      echo "Installing via Homebrew..."
      brew install glab
    else
      echo "ERROR: Install Homebrew first: https://brew.sh"
      exit 1
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    echo "On Windows, use one of:"
    echo "  winget install GLab.GLab"
    echo "  scoop install glab"
    echo ""
    if command -v winget &> /dev/null; then
      winget install --id GLab.GLab --accept-package-agreements
    elif command -v scoop &> /dev/null; then
      scoop install glab
    else
      echo "ERROR: Install winget or scoop first"
      exit 1
    fi
    ;;
  *)
    echo "ERROR: Unsupported OS. Install manually: https://gitlab.com/gitlab-org/cli#installation"
    exit 1
    ;;
esac

# Verify
if command -v glab &> /dev/null; then
  echo ""
  echo "✓ glab installed: $(glab version)"
  echo ""
  echo "Next: authenticate with GitLab"
  echo "  glab auth login --hostname gitlab.com"
else
  echo "ERROR: glab installation failed"
  exit 1
fi
