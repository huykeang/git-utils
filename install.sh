#!/bin/bash

# Where to install scripts
INSTALL_DIR="$HOME/.git-utils"

echo "🚀 Installing git-utils to $INSTALL_DIR..."

# A file on disk is a local checkout. Copy it into the curl install location.
# A piped curl install has no source file, so clone or pull from GitHub.
SOURCE_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -n "$SOURCE_DIR" ] && [ "$SOURCE_DIR" != "$INSTALL_DIR" ]; then
  echo "Updating $INSTALL_DIR from $SOURCE_DIR..."
  mkdir -p "$INSTALL_DIR"
  for script in "$SOURCE_DIR"/git-*; do
    if [ -f "$script" ]; then
      cp "$script" "$INSTALL_DIR/"
    fi
  done
  cp "$SOURCE_DIR/install.sh" "$INSTALL_DIR/install.sh"
elif [ -d "$INSTALL_DIR/.git" ]; then
  echo "Updating existing installation..."
  git -C "$INSTALL_DIR" pull --quiet
else
  git clone https://github.com/huykeang/git-utils.git "$INSTALL_DIR"
fi

# Prefer ~/.zshrc; fall back to ~/.bashrc when zshrc is missing
if [ -f "$HOME/.zshrc" ]; then
  SHELL_RC="$HOME/.zshrc"
else
  SHELL_RC="$HOME/.bashrc"
fi

# The saved line keeps $HOME literal, so match that text rather than the expanded path.
if [ ! -f "$SHELL_RC" ] || ! grep -q '\.git-utils' "$SHELL_RC"; then
  echo "Adding $INSTALL_DIR to PATH in $SHELL_RC..."
  echo 'export PATH="$HOME/.git-utils:$PATH"' >> "$SHELL_RC"
fi

# Make sure scripts are executable
chmod +x "$INSTALL_DIR"/*

echo
echo "✅ Installation complete!"
echo "You can now use your custom Git commands like:"
echo "    git cleanup-branches"
echo "    git branches-report"
echo "    git clone-gitlab-group-repos {YOUR_GROUP_URL}"
echo
echo "ℹ️  Run 'source $SHELL_RC' or open a new terminal to start using it."