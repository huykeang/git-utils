#!/bin/bash

# Where to install scripts
INSTALL_DIR="$HOME/.git-utils"

echo "🚀 Installing git-utils to $INSTALL_DIR..."

# Clone or update the repo
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "Updating existing installation..."
  git -C "$INSTALL_DIR" pull --quiet
else
  git clone https://github.com/huykeang/git-utils.git "$INSTALL_DIR"
fi

# Add to PATH in ~/.zshrc if not already there
if ! grep -q "$INSTALL_DIR" ~/.zshrc; then
  echo "Adding $INSTALL_DIR to PATH in ~/.zshrc..."
  echo 'export PATH="$HOME/.git-utils:$PATH"' >> ~/.zshrc
fi

# Make sure scripts are executable
chmod +x "$INSTALL_DIR"/*

echo
echo "✅ Installation complete!"
echo "You can now use your custom Git commands like:"
echo "    git cleanup-branches"
echo "    git branches-report"
echo
echo "ℹ️  Run 'source ~/.zshrc' or open a new terminal to start using it."