#!/bin/bash

set -e

# Step 1: Ensure pip is installed
if ! command -v pip &> /dev/null; then
    echo "🔧 pip not found. Installing pip..."
    sudo apt-get update && sudo apt-get install -y python3-pip
else
    echo "✅ pip is installed."
fi

# Step 2: Install pre-commit if not already installed
if ! command -v pre-commit &> /dev/null; then
    echo "🔧 pre-commit not found. Installing..."
    pip install pre-commit
else
    echo "✅ pre-commit is already installed."
fi

# Step 3: Check if virtualenv is needed
if ! python3 -m venv --help &> /dev/null; then
    echo "🔧 virtualenv is not installed. Installing python3-venv..."
    sudo apt-get install -y python3-venv
fi

# Step 4: Create and activate virtual environment
ENV_DIR="$HOME/.myenv"
if [ ! -d "$ENV_DIR" ]; then
    echo "🔧 Creating virtual environment in $ENV_DIR..."
    python3 -m venv "$ENV_DIR"
fi

echo "🔧 Activating virtual environment..."
source "$ENV_DIR/bin/activate"
 echo "⚠️ Virtual environment is active. Run 'deactivate' to exit it later."

# Step 5: Upgrade pip in virtual environment
echo "📦 Upgrading pip in the virtual environment..."
pip install --upgrade pip

# Step 6: Install Python dependencies for Python-based pre-commit hooks
echo "📦 Installing Python linters..."
pip install --upgrade pyupgrade autopep8 flake8 cpplint yamllint

# Step 7: Install Node.js tools (ESLint, Stylelint, HTMLHint)
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "🔧 Node.js or npm not found. Installing..."
    sudo apt update && sudo apt install -y nodejs npm
fi

echo "📦 Installing Node linters globally..."
npm install -g eslint stylelint htmlhint

# Step 8: Install Checkstyle_jar (Java) if not already installed
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

# Step 9: Install Go if not already installed
if ! command -v go &> /dev/null; then
    echo "🔧 Go not found. Installing..."
    sudo apt install -y golang
else
    echo "✅ Go is already installed."
fi

# Step 10: Generate .pre-commit-config.yaml in project root
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
        stages: [commit]

  - repo: https://github.com/asottile/setup-cfg-fmt
    rev: v2.8.0
    hooks:
      - id: setup-cfg-fmt
        stages: [commit]

  - repo: https://github.com/asottile/reorder-python-imports
    rev: v3.14.0
    hooks:
      - id: reorder-python-imports
        args: [--py39-plus, --add-import, 'from __future__ import annotations']
        stages: [commit]

  - repo: https://github.com/asottile/add-trailing-comma
    rev: v3.1.0
    hooks:
      - id: add-trailing-comma
        stages: [commit]

  - repo: https://github.com/asottile/pyupgrade
    rev: v3.19.1
    hooks:
      - id: pyupgrade
        args: [--py39-plus]
        stages: [commit]

  - repo: https://github.com/hhatto/autopep8
    rev: v2.3.2
    hooks:
      - id: autopep8
        stages: [commit]

  - repo: https://github.com/PyCQA/flake8
    rev: 7.2.0
    hooks:
      - id: flake8
        stages: [commit]
        pass_filenames: false  # Only one pass_filenames line

  - repo: https://github.com/golangci/golangci-lint
    rev: v2.1.2
    hooks:
      - id: golangci-lint
        name: Go linter
        files: \.go$
        types: [file]
        stages: [commit]

  - repo: https://github.com/bridgecrewio/checkov
    rev: 3.2.406  # Use the latest version
    hooks:
      - id: checkov
        name: Checkov Security Scanner
        entry: checkov -d .
        language: python
        pass_filenames: false
        stages: [commit]

  - repo: https://github.com/eslint/eslint.git
    rev: v9.24.0  # instead of a v9 tag
    hooks:
      - id: eslint
        args: ['.']
        pass_filenames: true
        stages: [commit]

  - repo: local
    hooks:
      - id: custom-python-linter
        name: Custom Python Linter
        entry: custom_hooks/custom_linter.py
        language: system
        types: [python]
        description: Runs a custom Python linter to enforce coding standards.
        stages: [commit]


      - id: check-large-files
        name: Check for Large Files
        entry: custom_hooks/check_large_files.sh
        language: script
        types: [file]
        description: Prevents committing files larger than 1MB.
        stages: [commit]

      - id: golang-setup
        name: Go Environment Setup
        language: system
        entry: go version
        files: \.go$
        stages: [commit]

      # HTML Linting
      - id: htmlhint
        name: HTMLHint
        entry: htmlhint
        language: system
        types: [text]
        files: \.html$
        stages: [commit]

      - id: stylelint
        name: Stylelint for CSS
        entry: stylelint "**/*.css"
        language: node
        pass_filenames: false
        files: \.css$
        stages: [commit]

      # Java Linting using Checkstyle
      - id: checkstyle-java
        name: Checkstyle for Java
        entry: checkstyle -c /google_checks.xml
        language: system
        types: [java]
        files: \.java$
        stages: [commit]

      # YAML Linting
      - id: yamllint
        name: YAML Linter (yamllint)
        entry: yamllint -c .yamllint
        language: system
        files: \.ya?ml$
        stages: [commit]

      # C Language Linting using cpplint
      - id: cpplint-c
        name: cpplint for C
        entry: cpplint
        language: python
        types: [c]
        files: \.(c|h)$
        stages: [commit]

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
        stages: [commit]
        args: []
        exclude: ''
EOF

# Step 11: Initialize pre-commit hooks
echo "🔗 Installing pre-commit hooks from config..."
pre-commit install
pre-commit install --install-hooks  # Optional: Auto-install hooks for all environments

# Step 12: Set up custom hooks
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

# Step 13: Create the large file checker script
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

# Step 14: Validate pre-commit config
echo "🔍 Validating .pre-commit-config.yaml..."
pre-commit validate-config

echo "✅ .pre-commit-config.yaml is valid."

# Step 15: Add custom yamllint configuration
echo "🧾 Adding custom .yamllint config..."
cat <<'EOF' > .yamllint
extends: default

rules:
  line-length:
    max: 150
    level: error
EOF
