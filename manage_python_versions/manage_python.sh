#!/bin/bash

# Detect OS
OS="$(uname -s)"

detect_os() {
    case "$OS" in
        Darwin)
            echo "macOS"
            ;;
        Linux)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                echo "$NAME"
            else
                echo "Linux"
            fi
            ;;
        *)
            echo "Unsupported"
            ;;
    esac
}

while true; do
    echo "========================================================"
    echo "   Python Environment Tool"
    echo "========================================================"
    echo "0) Exit"
    echo "1) Check if Homebrew and pyenv are installed"
    echo "2) Install Homebrew (or update if already installed)"
    echo "3) Install pyenv (or update if already installed)"
    echo "4) List all installed Python versions (Homebrew + pyenv + system)"
    echo "5) Show current active Python version (with source)"
    echo "6) Install a Python version"
    echo "7) Set Global/Local Python version (pyenv)"
    echo "8) Uninstall Python version"
    echo "9) Detect and fix Python PATH conflicts"
    echo "10) Repair broken Python setup"
    echo "============================"
    echo "     "
    echo -n "Enter your choice: "
    read choice

    case $choice in
        1)
            echo "🔍 Checking installations..."
            if command -v brew &>/dev/null; then
                echo "✅ Homebrew is installed: $(brew --version | head -n 1)"
            else
                echo "❌ Homebrew is NOT installed."
            fi

            if command -v pyenv &>/dev/null; then
                echo "✅ pyenv is installed: $(pyenv --version)"
            else
                echo "❌ pyenv is NOT installed."
            fi
            ;;
        2)
            if command -v brew &>/dev/null; then
                echo "✅ Homebrew is already installed: $(brew --version | head -n 1)"
                echo -n "🔄 Do you want to check for updates? (y/N): "
                read -r update_choice
                if [[ "$update_choice" == "y" || "$update_choice" == "Y" ]]; then
                    echo "🔍 Checking for Homebrew updates..."
                    brew update
                    echo "✅ Homebrew updated."
                else
                    echo "⏭️ Skipping update."
                fi
            else
                echo "📦 Installing Homebrew..."
                CURRENT_OS=$(detect_os)
                if [ "$CURRENT_OS" = "macOS" ]; then
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                elif [[ "$CURRENT_OS" == "Ubuntu"* || "$CURRENT_OS" == "Debian"* ]]; then
                    sudo apt update && sudo apt install -y build-essential curl file git
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                else
                    echo "❌ Homebrew installation not supported on $CURRENT_OS"
                fi
            fi
            ;;
        3)
            if command -v pyenv &>/dev/null; then
                echo "✅ pyenv is already installed: $(pyenv --version)"
                echo -n "🔄 Do you want to update pyenv? (y/N): "
                read -r update_choice
                if [[ "$update_choice" == "y" || "$update_choice" == "Y" ]]; then
                    CURRENT_OS=$(detect_os)
                    if [[ "$CURRENT_OS" = "macOS" ]]; then
                        echo "🔄 Updating pyenv via Homebrew..."
                        brew upgrade pyenv
                    elif [[ "$CURRENT_OS" == "Ubuntu"* || "$CURRENT_OS" == "Debian"* ]]; then
                        echo "🔄 Updating pyenv via git..."
                        PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
                        if [ -d "$PYENV_ROOT" ]; then
                            git -C "$PYENV_ROOT" pull
                        else
                            echo "❌ pyenv directory not found at $PYENV_ROOT"
                        fi
                    else
                        echo "❌ pyenv update not supported on $CURRENT_OS"
                    fi
                    echo "✅ pyenv updated."
                else
                    echo "⏭️ Skipping pyenv update."
                fi
            else
                echo "📦 Installing pyenv..."
                CURRENT_OS=$(detect_os)

                # Remove any existing pyenv installation
                echo "🗑️ Removing old pyenv directories if they exist..."
                rm -rf ~/.pyenv
                if command -v brew &>/dev/null; then
                    rm -rf "$(brew --prefix pyenv 2>/dev/null)" 2>/dev/null || true
                fi

                if [[ "$CURRENT_OS" = "macOS" ]]; then
                    brew install pyenv
                elif [[ "$CURRENT_OS" == "Ubuntu"* || "$CURRENT_OS" == "Debian"* ]]; then
                    sudo apt update
                    sudo apt install -y make build-essential libssl-dev zlib1g-dev \
                        libbz2-dev libreadline-dev libsqlite3-dev curl \
                        libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev git

                    curl https://pyenv.run | bash
                else
                    echo "❌ pyenv installation not supported on $CURRENT_OS"
                    continue
                fi

                # Detect shell config file (bash or zsh)
                SHELL_RC="$HOME/.bashrc"
                if [ -n "$ZSH_VERSION" ] || [[ "$SHELL" == *"zsh" ]]; then
                    SHELL_RC="$HOME/.zshrc"
                fi

                # Add pyenv setup if not already present
                if ! grep -q 'pyenv init' "$SHELL_RC"; then
                    echo -e '\n# Pyenv setup' >> "$SHELL_RC"
                    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> "$SHELL_RC"
                    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> "$SHELL_RC"
                    echo 'eval "$(pyenv init - bash)"' >> "$SHELL_RC"
                    echo 'eval "$(pyenv virtualenv-init -)"' >> "$SHELL_RC"
                fi

                # Load pyenv immediately for current session
                export PYENV_ROOT="$HOME/.pyenv"
                export PATH="$PYENV_ROOT/bin:$PATH"
                eval "$(pyenv init - bash)"
                eval "$(pyenv virtualenv-init -)"

                echo "✅ pyenv installed and configured successfully!"
            fi
            ;;
        4)
            echo "📦 Listing installed Python versions..."

            # Homebrew
            if command -v brew &>/dev/null; then
                echo "🔹 Homebrew Python versions:"
                brew_py_versions=$(brew list --versions python python@* 2>/dev/null | grep -E '^python(@[0-9\.]+)?\s')
                if [ -n "$brew_py_versions" ]; then
                    echo "$brew_py_versions"
                else
                    echo "   (No Python found via Homebrew)"
                fi
            else
                echo "❌ Homebrew not installed, skipping..."
            fi

            # pyenv
            if command -v pyenv &>/dev/null; then
                echo "🔹 pyenv Python versions:"
                pyenv versions --bare 2>/dev/null | sed 's/^/    /' || echo "   (No Python versions installed via pyenv)"
            else
                echo "❌ pyenv not installed, skipping..."
            fi

            # System Python
            echo "🔹 System Python version:"
            if command -v python3 &>/dev/null; then
                SYS_PY_PATH=$(command -v python3)
                SYS_PY_VER=$(python3 --version 2>/dev/null)
                echo "    $SYS_PY_VER (path: $SYS_PY_PATH)"
            else
                echo "   ❌ python3 not found in system PATH"
            fi
            ;;

        5)
            echo "🐍 Current active Python version:"
            if command -v python3 &>/dev/null; then
                PY_PATH=$(which python3)
                PY_VERSION=$(python3 --version 2>/dev/null)

                echo "🔹 Path: $PY_PATH"
                echo "🔹 Version: $PY_VERSION"

                # Detect source
                if [[ "$PY_PATH" == *".pyenv/shims"* ]]; then
                    echo "📦 Source: pyenv"
                elif [[ "$PY_PATH" == *"brew"* ]]; then
                    echo "📦 Source: Homebrew"
                elif [[ "$PY_PATH" == "/usr/bin/python3" ]]; then
                    echo "📦 Source: System Python"
                else
                    echo "📦 Source: Unknown (custom install?)"
                fi
            else
                echo "❌ Python3 not found in PATH"
            fi

            # Show pyenv global and local versions if pyenv is installed
            if command -v pyenv &>/dev/null; then
                PYENV_GLOBAL=$(pyenv global 2>/dev/null)
                PYENV_LOCAL=$(pyenv local 2>/dev/null)
                echo "🔹 pyenv global version: $PYENV_GLOBAL"
                if [ "$PYENV_LOCAL" != "$PYENV_GLOBAL" ]; then
                    echo "🔹 pyenv local version: $PYENV_LOCAL"
                fi
            fi
            ;;
        6)
            echo "📥 Install a Python version"
            echo -n "Choose source (h = Homebrew, p = pyenv): "
            read -r source_choice

            if [[ "$source_choice" == "h" ]]; then
                if ! command -v brew &>/dev/null; then
                    echo "❌ Homebrew not installed."
                    continue
                fi

                echo "🔍 Fetching available Python formulae from Homebrew..."
                brew_versions=""
                i=0
                while read -r line; do
                    brew_versions="$brew_versions $line"
                    eval "brew_version_$i=\"$line\""
                    i=$((i+1))
                done < <(brew search "^python@" | grep -E '^python@[0-9\.]+$')

                if [ "$i" -eq 0 ]; then
                    echo "❌ No Python versions found via Homebrew."
                    continue
                fi

                echo "Available Python versions via Homebrew:"
                j=0
                for version in $brew_versions; do
                    echo "$j) $version"
                    j=$((j+1))
                done

                echo -n "Enter the number of the version to install: "
                read -r selection
                eval "selected_version=\$brew_version_$selection"

                if [ -n "$selected_version" ]; then
                    echo "📦 Installing $selected_version via Homebrew..."
                    brew install "$selected_version"
                else
                    echo "❌ Invalid selection."
                fi

            elif [[ "$source_choice" == "p" ]]; then
                if ! command -v pyenv &>/dev/null; then
                    echo "❌ pyenv not installed."
                    continue
                fi

                echo "🔍 Fetching available Python versions via pyenv..."

                pyenv_versions=""
                i=0
                pyenv install --list 2>/dev/null | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | sed 's/^[ \t]*//' | sort -Vr | head -n 20 | while read -r line; do
                    pyenv_versions="$pyenv_versions $line"
                    eval "pyenv_version_$i=\"$line\""
                    i=$((i+1))
                done

                # Re-evaluate variables after while loop (since while in a pipe runs in a subshell)
                pyenv_versions_list=$(pyenv install --list 2>/dev/null | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | sed 's/^[ \t]*//' | sort -Vr | head -n 20)
                i=0
                pyenv_versions=""
                for line in $pyenv_versions_list; do
                    pyenv_versions="$pyenv_versions $line"
                    eval "pyenv_version_$i=\"$line\""
                    i=$((i+1))
                done

                if [ "$i" -eq 0 ]; then
                    echo "❌ No installable versions found via pyenv."
                    continue
                fi

                echo "Available Python versions via pyenv (latest 20):"
                echo "e) Exit without installing"
                j=0
                for version in $pyenv_versions; do
                    echo "$j) $version"
                    j=$((j+1))
                done

                echo -n "Enter the number of the version to install (or 'e' to exit): "
                read -r selection

                if [[ "$selection" == "e" ]]; then
                    echo "❌ Installation canceled by user."
                    continue
                elif [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 0 ] && [ "$selection" -lt "$i" ]; then
                    eval "selected_version=\$pyenv_version_$selection"
                    echo "📦 Installing Python $selected_version via pyenv..."
                    pyenv install "$selected_version"
                else
                    echo "❌ Invalid selection."
                fi

            fi
            ;;

        7)
            if ! command -v pyenv &>/dev/null; then
                echo "❌ pyenv not installed."
                continue
            fi

            echo "🔍 Installed pyenv Python versions:"
            pyenv_versions=""
            i=0
            while read -r line; do
                pyenv_versions="$pyenv_versions $line"
                eval "pyenv_version_$i=\"$line\""
                i=$((i+1))
            done < <(pyenv versions --bare 2>/dev/null)

            if [ "$i" -eq 0 ]; then
                echo "   (No Python versions installed via pyenv)"
                continue
            fi

            j=0
            for version in $pyenv_versions; do
                echo "$j) $version"
                j=$((j+1))
            done

            echo -n "Enter the number of the version to set: "
            read -r selection

            if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 0 ] && [ "$selection" -lt "$i" ]; then
                eval "selected_version=\$pyenv_version_$selection"
                echo -n "Set as (g)lobal or (l)ocal? "
                read -r scope
                if [[ "$scope" == "g" ]]; then
                    pyenv global "$selected_version"
                    echo "✅ Set global Python version to $selected_version"
                elif [[ "$scope" == "l" ]]; then
                    pyenv local "$selected_version"
                    echo "✅ Set local Python version to $selected_version"
                else
                    echo "❌ Invalid scope selection."
                fi
            else
                echo "❌ Invalid selection."
            fi
            ;;

        8)
            echo "🗑️ Uninstall a Python version"
            echo -n "Choose source to uninstall from (h = Homebrew, p = pyenv): "
            read -r source_choice

            if [[ "$source_choice" == "h" ]]; then
                if ! command -v brew &>/dev/null; then
                    echo "❌ Homebrew not installed."
                    continue
                fi

                brew_versions=""
                i=0
                while read -r line; do
                    brew_versions="$brew_versions $line"
                    eval "brew_version_$i=\"$line\""
                    i=$((i+1))
                done < <(brew list --versions python python@* 2>/dev/null | awk '{print $1}')

                if [ "$i" -eq 0 ]; then
                    echo "❌ No Python versions found via Homebrew."
                    continue
                fi

                echo "Installed Python versions via Homebrew:"
                j=0
                for version in $brew_versions; do
                    echo "$j) $version"
                    j=$((j+1))
                done

                echo -n "Enter the number of the version to uninstall: "
                read -r selection
                eval "selected_version=\$brew_version_$selection"

                if [ -n "$selected_version" ]; then
                    echo "🗑️ Uninstalling $selected_version via Homebrew..."
                    brew uninstall "$selected_version"
                else
                    echo "❌ Invalid selection."
                fi

            elif [[ "$source_choice" == "p" ]]; then
                if ! command -v pyenv &>/dev/null; then
                    echo "❌ pyenv not installed."
                    continue
                fi

                pyenv_versions=""
                i=0
                while read -r line; do
                    pyenv_versions="$pyenv_versions $line"
                    eval "pyenv_version_$i=\"$line\""
                    i=$((i+1))
                done < <(pyenv versions --bare 2>/dev/null)

                if [ "$i" -eq 0 ]; then
                    echo "❌ No Python versions found via pyenv."
                    continue
                fi

                echo "Installed Python versions via pyenv:"
                j=0
                for version in $pyenv_versions; do
                    echo "$j) $version"
                    j=$((j+1))
                done

                echo -n "Enter the number of the version to uninstall: "
                read -r selection
                if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 0 ] && [ "$selection" -lt "$i" ]; then
                    eval "selected_version=\$pyenv_version_$selection"
                    echo "🗑️ Uninstalling Python $selected_version via pyenv..."
                    pyenv uninstall -f "$selected_version"
                else
                    echo "❌ Invalid selection."
                fi
            else
                echo "❌ Invalid source choice."
            fi
            ;;

        9)
            echo "🔎 Detecting Python PATH conflicts..."

            python_paths=""
            i=0
            while read -r line; do
                python_paths="$python_paths $line"
                eval "python_path_$i=\"$line\""
                i=$((i+1))
            done < <(type -a -p python3 2>/dev/null | uniq)

            if [ "$i" -eq 0 ]; then
                echo "❌ No python3 found in PATH."
                continue
            fi

            echo "Python executables found in PATH (priority order):"
            j=0
            for path in $python_paths; do
                echo "$j) $path"
                j=$((j+1))
            done

            # Identify sources
            brew_found=false
            pyenv_found=false
            system_found=false
            for idx in $(seq 0 $((i-1))); do
                eval "path=\$python_path_$idx"
                if [[ "$path" == *".pyenv/shims"* ]]; then
                    pyenv_found=true
                elif [[ "$path" == *"brew"* ]]; then
                    brew_found=true
                elif [[ "$path" == "/usr/bin/python3" ]]; then
                    system_found=true
                fi
            done

            # Show which is active
            eval "active_path=\$python_path_0"
            echo ""
            echo "🔹 Active python3: $active_path"
            if [[ "$active_path" == *".pyenv/shims"* ]]; then
                echo "📦 Source: pyenv"
            elif [[ "$active_path" == *"brew"* ]]; then
                echo "📦 Source: Homebrew"
            elif [[ "$active_path" == "/usr/bin/python3" ]]; then
                echo "📦 Source: System Python"
            else
                echo "📦 Source: Unknown"
            fi

            # Warn about conflicts
            if $brew_found && $pyenv_found; then
                if [[ "$active_path" == *"brew"* ]]; then
                    echo "⚠️  Conflict detected: Both Homebrew and pyenv Python versions are in PATH."
                    echo "   Homebrew Python is taking precedence over pyenv."
                    echo "   To fix: Move pyenv shims earlier in your PATH or set pyenv global/local version."
                elif [[ "$active_path" == *".pyenv/shims"* ]]; then
                    echo "⚠️  Both Homebrew and pyenv Python versions are in PATH."
                    echo "   pyenv Python is taking precedence over Homebrew."
                fi
            elif $brew_found && $system_found && ! $pyenv_found; then
                echo "ℹ️  Both Homebrew and system Python are in PATH."
            elif $pyenv_found && $system_found && ! $brew_found; then
                echo "ℹ️  Both pyenv and system Python are in PATH."
            fi

            echo ""
            echo "To fix conflicts, you can:"
            echo " - Adjust your PATH in ~/.bashrc or ~/.zshrc"
            echo " - Use pyenv to set global/local Python version"
            echo " - Uninstall unnecessary Python versions"
            ;;

        10)
            echo "🛠️ Checking and repairing Python setup..."

            # Check if python3 symlink is broken
            PY_PATH=$(command -v python3 2>/dev/null)
            if [ -n "$PY_PATH" ]; then
                if [ ! -x "$PY_PATH" ]; then
                    echo "❌ python3 points to a missing or non-executable binary: $PY_PATH"
                    # Try to reset symlink if Homebrew is installed
                    if command -v brew &>/dev/null; then
                        echo "🔄 Attempting to relink Homebrew python3..."
                        brew link --overwrite python || brew link --overwrite python3
                    fi
                    # Try to reset symlink if pyenv is installed
                    if command -v pyenv &>/dev/null; then
                        echo "🔄 Attempting to rehash pyenv shims..."
                        pyenv rehash
                    fi
                else
                    echo "✅ python3 binary is present: $PY_PATH"
                fi
            else
                echo "❌ python3 not found in PATH."
            fi

            # Check if pyenv is broken
            if command -v pyenv &>/dev/null; then
                if ! pyenv versions &>/dev/null; then
                    echo "❌ pyenv appears broken. Attempting auto-reinstall..."
                    # Remove and reinstall pyenv
                    rm -rf ~/.pyenv
                    if command -v brew &>/dev/null; then
                        brew uninstall pyenv || true
                        brew install pyenv
                    else
                        curl https://pyenv.run | bash
                    fi
                    echo "✅ pyenv reinstalled."
                else
                    echo "✅ pyenv is working."
                fi
            fi

            echo "🛠️ Repair complete."
            ;;
        0)
            echo "👋 Exiting..."
            exit 0
            ;;
        *)
            echo "❌ Invalid choice. Please select a valid option."
            ;;
    esac

    echo "" # Blank line for readability
done
