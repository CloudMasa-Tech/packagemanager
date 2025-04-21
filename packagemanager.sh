#!/bin/bash

set -e

# Step 1: Ensure pip is installed
if ! command -v pip &> /dev/null; then
    echo "🔧 pip not found. Installing pip..."
    sudo apt-get update && sudo apt-get install -y python3-pip
else
    echo "✅ pip is installed."
fi

# Step 2: Check if python3-venv is installed
if ! python3 -m venv --help &> /dev/null; then
    echo "🔧 python3-venv is not installed. Installing..."
    sudo apt-get update && sudo apt-get install -y python3-venv
fi

# Step 3: Create and activate virtual environment
ENV_DIR="$HOME/.venv"
if [ ! -d "$ENV_DIR" ]; then
    echo "🔧 Creating virtual environment in $ENV_DIR..."
    python3 -m venv "$ENV_DIR"
fi

echo "🔧 Activating virtual environment..."
source "$ENV_DIR/bin/activate"
echo "⚠️ Virtual environment is active. Run 'deactivate' to exit it later."

# Step 4: Upgrade pip and install pre-commit in the virtual environment
echo "📦 Upgrading pip and installing pre-commit in the virtual environment..."
pip install --upgrade pip
pip install pre-commit

# Step 5: Install Python dependencies for Python-based pre-commit hooks
echo "📦 Installing Python linters..."
pip install --upgrade pyupgrade autopep8 flake8 cpplint yamllint

# Step 6: Install Node.js tools (ESLint, Stylelint, HTMLHint)
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "🔧 Node.js or npm not found. Installing..."
    sudo apt update && sudo apt install -y nodejs npm
fi

echo "📦 Installing Node linters globally..."

# Set up user-owned global npm directory to avoid EACCES errors
if ! npm config get prefix | grep -q "$HOME/.npm-global"; then
  echo "🔧 Setting up a user-level global npm directory to avoid permission issues..."
  mkdir -p "$HOME/.npm-global"
  npm config set prefix "$HOME/.npm-global"
  
  SHELL_CONFIG="$HOME/.bashrc"
  if [ -n "$ZSH_VERSION" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
  fi

  if ! grep -q 'export PATH=$HOME/.npm-global/bin:$PATH' "$SHELL_CONFIG"; then
    echo 'export PATH=$HOME/.npm-global/bin:$PATH' >> "$SHELL_CONFIG"
    echo "✅ Added npm-global path to $SHELL_CONFIG"
    export PATH="$HOME/.npm-global/bin:$PATH"
  fi
fi

# Install Node linters without sudo
npm install -g eslint stylelint htmlhint

# Step 7: Install Checkstyle_jar (Java) if not already installed
LATEST_VERSION=$(curl -s https://api.github.com/repos/checkstyle/checkstyle/releases/latest | grep -oP '"tag_name":\s*"checkstyle-\K[^"]+')
CHECKSTYLE_VERSION="$LATEST_VERSION"
CHECKSTYLE_JAR="checkstyle-${CHECKSTYLE_VERSION}-all.jar"
CHECKSTYLE_URL="https://github.com/checkstyle/checkstyle/releases/download/checkstyle-${CHECKSTYLE_VERSION}/${CHECKSTYLE_JAR}"
INSTALL_DIR="$HOME/.local/bin"

mkdir -p "$INSTALL_DIR"

if [ ! -f "$INSTALL_DIR/$CHECKSTYLE_JAR" ]; then
    echo "🔧 Installing Checkstyle version ${CHECKSTYLE_VERSION}..."
    curl -L -o "$INSTALL_DIR/$CHECKSTYLE_JAR" "$CHECKSTYLE_URL"
else
    echo "✅ Checkstyle ${CHECKSTYLE_VERSION} is already installed."
fi

PROFILE_FILE="$HOME/.bashrc"
if ! grep -q "alias checkstyle=" "$PROFILE_FILE"; then
    echo "📌 Creating alias for checkstyle..."
    echo "alias checkstyle='java -jar $INSTALL_DIR/$CHECKSTYLE_JAR'" >> "$PROFILE_FILE"
    echo "⚠️ Please run 'source $PROFILE_FILE' or restart your terminal to activate the 'checkstyle' alias."
else
    echo "🔁 Alias for checkstyle already exists."
fi

# Step 8: Install Go if not already installed
if ! command -v go &> /dev/null; then
    echo "🔧 Go not found. Installing..."
    sudo apt install -y golang
else
    echo "✅ Go is already installed."
fi

# Step 9: Generate .pre-commit-config.yaml in project root
echo "📝 Writing .pre-commit-config.yaml to project root..."
cat <<'EOF' > "$PWD/.pre-commit-config.yaml"
---
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
        name: Ensure files end with a newline
      - id: check-yaml
      - id: debug-statements
      - id: double-quote-string-fixer
        name: Enforce double quotes for strings
      - id: name-tests-test
      - id: requirements-txt-fixer
      - id: check-docstring-first
      - id: check-added-large-files
        args: ['--maxkb=20000']
      - id: check-docstring-first
      - id: check-json
      - id: detect-private-key
      - id: sort-simple-yaml
        stages: [pre-commit]

  - repo: https://github.com/asottile/setup-cfg-fmt
    rev: v2.8.0
    hooks:
      - id: setup-cfg-fmt
        stages: [pre-commit]

  - repo: https://github.com/asottile/reorder-python-imports
    rev: v3.14.0
    hooks:
      - id: reorder-python-imports
        args: [--py39-plus, --add-import, 'from __future__ import annotations']
        stages: [pre-commit]

  - repo: https://github.com/asottile/add-trailing-comma
    rev: v3.1.0
    hooks:
      - id: add-trailing-comma
        stages: [pre-commit]

  - repo: https://github.com/asottile/pyupgrade
    rev: v3.19.1
    hooks:
      - id: pyupgrade
        args: [--py39-plus]
        stages: [pre-commit]

  - repo: https://github.com/hhatto/autopep8
    rev: v2.3.2
    hooks:
      - id: autopep8
        stages: [pre-commit]

  - repo: https://github.com/PyCQA/flake8
    rev: 7.2.0
    hooks:
      - id: flake8
        stages: [pre-commit]
        pass_filenames: false  # Only one pass_filenames line

  - repo: https://github.com/golangci/golangci-lint
    rev: v2.1.2
    hooks:
      - id: golangci-lint
        name: Go linter
        files: \.go$
        types: [file]
        stages: [pre-commit]

  - repo: https://github.com/bridgecrewio/checkov
    rev: 3.2.406  # Use the latest version
    hooks:
      - id: checkov
        name: Checkov Security Scanner
        entry: checkov -d .
        language: python
        pass_filenames: false
        stages: [pre-commit]

  - repo: https://github.com/eslint/eslint.git
    rev: v9.24.0  # instead of a v9 tag
    hooks:
      - id: eslint
        args: ['.']
        pass_filenames: true
        stages: [pre-commit]

  - repo: local
    hooks:
      - id: custom-python-linter
        name: Custom Python Linter
        entry: custom_hooks/custom_linter.py
        language: system
        types: [python]
        description: Runs a custom Python linter to enforce coding standards.
        stages: [pre-commit]


      - id: check-large-files
        name: Check for Large Files
        entry: custom_hooks/check_large_files.sh
        language: script
        types: [file]
        description: Prevents committing files larger than 1MB.
        stages: [pre-commit]

      - id: golang-setup
        name: Go Environment Setup
        language: system
        entry: go version
        files: \.go$
        stages: [pre-commit]

      # HTML Linting
      - id: htmlhint
        name: HTMLHint
        entry: htmlhint
        language: system
        types: [text]
        files: \.html$
        stages: [pre-commit]

      - id: stylelint
        name: Stylelint for CSS
        entry: stylelint "**/*.css"
        language: node
        pass_filenames: false
        files: \.css$
        stages: [pre-commit]

      # Java Linting using Checkstyle
      - id: checkstyle-java
        name: Checkstyle for Java
        entry: checkstyle -c /google_checks.xml
        language: system
        types: [java]
        files: \.java$
        stages: [pre-commit]

      # YAML Linting
      - id: yamllint
        name: YAML Linter (yamllint)
        entry: yamllint -c .yamllint
        language: system
        files: \.ya?ml$
        stages: [pre-commit]

      # C Language Linting using cpplint
      - id: cpplint-c
        name: cpplint for C
        entry: cpplint
        language: python
        types: [c]
        files: \.(c|h)$
        stages: [pre-commit]

  - repo: local
    hooks:
      - id: custom-autocorrect
        name: Custom AutoCorrect
        entry: custom_hooks/autocorrect.sh
        language: script
        pass_filenames: true
        always_run: true
        types: [file]
        verbose: true
        require_serial: true
        stages: [pre-commit]
        args: []
        exclude: ''
EOF

# Step 10: Initialize pre-commit hooks
echo "🔗 Installing pre-commit hooks from config..."
pre-commit install
pre-commit install --install-hooks  # Optional: Auto-install hooks for all environments

# Step 11: Set up custom hooks
echo "🔧 Setting up custom hooks..."
mkdir -p custom_hooks

# Custom Python linter script
cat <<'EOF' > custom_hooks/custom_linter.py
#!/usr/bin/env python3
from __future__ import annotations
import sys

def check_code(file_path):
    with open(file_path) as file:
        lines = file.readlines()
        for line_num, line in enumerate(lines, 1):
            if line.startswith("import"):
                print(f"Line {line_num}: Ensure correct import order.")

if __name__ == "__main__":
    for file_path in sys.argv[1:]:
        check_code(file_path)
EOF
chmod +x custom_hooks/custom_linter.py

# Step 12: Create the large file checker script
cat <<'EOF' > custom_hooks/check_large_files.sh
#!/bin/bash
: "${MAX_SIZE:=20971520}" # 20MB in bytes
for file in "$@"; do
    if [ "$(stat -c %s "$file")" -gt "$MAX_SIZE" ]; then
        echo "❌ File $file is too large! Size exceeds $(($MAX_SIZE / 20971520)) MB."
        exit 1
    fi
done
EOF
chmod +x custom_hooks/check_large_files.sh

# Custom AutoCorrect script
cat <<'EOF' > custom_hooks/autocorrect.sh
#!/bin/bash

for file in "\$@"; do
  if [[ -f "\$file" ]]; then
    # Skip YAML config or Python scripts
    [[ "\$file" == ".pre-commit-config.yaml" || "\$file" == *.yaml || "\$file" == *.yml || "\$file" == *.py ]] && continue

    echo "Autocorrecting: \$file"

    # Fix double spaces
    sed -i 's/ \+/ /g' "\$file"

    # Ensure files end with a newline
    sed -i -e '\$a\' "\$file"

    # Remove trailing whitespace
    sed -i 's/[ \t]*\$//' "\$file"

    # Replace single quotes with double quotes (simple strings only)
    sed -i "s/'\([^']*\)'/\"\1\"/g" "\$file"

    echo "Fixed: \$file"
  fi
done

# Always exit 0 to prevent pre-commit from marking it as failed
exit 0
EOF

chmod +x custom_hooks/autocorrect.sh

echo "✅ Custom hooks have been created."

echo -e "\n🎉 Pre-commit setup complete and ready to use!"

# Step 13: Validate pre-commit config
echo "🔍 Validating .pre-commit-config.yaml..."
pre-commit validate-config

echo "✅ .pre-commit-config.yaml is valid."

# Step 14: Add custom yamllint configuration
echo "🧾 Adding custom .yamllint config..."
cat <<'EOF' > .yamllint
extends: default

rules:
  line-length:
    max: 150
    level: error
EOF

# Step 15: Link global .pre-commit-config.yaml to all Git-enabled subdirectories (if any)
echo "🔗 Linking global .pre-commit-config.yaml to all Git-enabled subdirectories..."

GLOBAL_CONFIG="$PWD/.pre-commit-config.yaml"

# Find all Git-enabled subdirectories
find . -type d -name ".git" | while read -r gitdir; do
    dir=$(dirname "$gitdir")
    TARGET_CONFIG="$dir/.pre-commit-config.yaml"
    if [ "$GLOBAL_CONFIG" != "$TARGET_CONFIG" ]; then
        echo "📁 Linking config to $dir"
        ln -sf "$GLOBAL_CONFIG" "$TARGET_CONFIG"
    fi
done

echo "✅ Linking complete."

# Final message
echo -e "\n🎉 Pre-commit setup complete and ready to use in all Git-enabled directories!"
