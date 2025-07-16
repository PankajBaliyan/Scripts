#!/usr/bin/env bash

# === COLOR SETUP ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# -----------------------------------------------
# 🌍 Detect Operating System and Persist Choice
# -----------------------------------------------

if [[ -z "$OS_TYPE" ]]; then
    UNAME_OUT="$(uname -s)"
    case "${UNAME_OUT}" in
    Darwin*) OS_TYPE="macos" ;;
    Linux*) OS_TYPE="linux" ;;
    *) OS_TYPE="unknown" ;;
    esac

    echo ""
    echo -e "${BLUE}💻 Detected OS: ${OS_TYPE}${NC}"
    echo ""

    # Export for current session
    export OS_TYPE

    # Optionally persist to file for next scripts
    # echo "export OS_TYPE=$OS_TYPE" > .os_env_config
fi

# -----------------------------------------------
# ❗ Check for invalid characters in project folder name
# -----------------------------------------------

PROJECT_DIR="$(pwd)"
if [[ "$PROJECT_DIR" == *" "* || "$PROJECT_DIR" == *"'"* ]]; then
    echo -e "${RED}🚫 Folder path contains space or apostrophe:${NC} \"$PROJECT_DIR\""
    echo -e "${YELLOW}💡 Please rename the folder to remove spaces or apostrophes before continuing.${NC}"
    echo -e "${BLUE}📦 Recommended format: use hyphens (-) or underscores (_) instead.${NC}"
    echo ""
    exit 1
fi

# === Helper function to read input case-insensitive and trim whitespace ===
read_input() {
    local prompt=$1
    local default=$2
    local input
    read -t 20 -p "$prompt" input || input="$default"
    # convert to lowercase & trim spaces
    input=$(echo "$input" | tr '[:upper:]' '[:lower:]' | xargs)
    echo "$input"
}

# --------------------------------------------------
# 🔹 FEATURE 1: Check Required Dependencies
# --------------------------------------------------

echo -e "${YELLOW}🔍 Checking required dependencies for environment setup...${NC}"

REQUIRED_CMDS=(python3 pip3 pipenv jupyter pyenv pipx)
MISSING=0

install_cmd() {
    local cmd="$1"

    case "$cmd" in
    python3)
        if [[ "$OS_TYPE" == "linux" ]]; then
            echo -e "${YELLOW}📦 Installing python3 via apt...${NC}"
            sudo apt update && sudo apt install -y python3
        elif [[ "$OS_TYPE" == "macos" ]]; then
            echo -e "${YELLOW}📦 Installing python3 via Homebrew...${NC}"
            brew install python
        fi
        ;;
    pip3)
        if [[ "$OS_TYPE" == "linux" ]]; then
            echo -e "${YELLOW}📦 Installing pip3 via apt...${NC}"
            sudo apt install -y python3-pip
        elif [[ "$OS_TYPE" == "macos" ]]; then
            echo -e "${YELLOW}📦 Ensuring pip3 is available on macOS...${NC}"
            brew install python # Includes pip3
        fi
        ;;
    pipx)
        echo -e "${YELLOW}📦 Installing pipx...${NC}"
        if [[ "$OS_TYPE" == "linux" ]]; then
            sudo apt install -y pipx
        elif [[ "$OS_TYPE" == "macos" ]]; then
            brew install pipx
        fi
        export PATH="$HOME/.local/bin:$PATH"
        ;;
    pipenv)
        if ! command -v pipx >/dev/null 2>&1; then
            install_cmd "pipx"
        fi
        echo -e "${YELLOW}📦 Installing pipenv via pipx...${NC}"
        if [[ "$OS_TYPE" == "linux" ]]; then
            pipx install pipenv
        elif [[ "$OS_TYPE" == "macos" ]]; then
            brew install pipenv
        fi
        ;;
    jupyter)
        if ! command -v pipx >/dev/null 2>&1; then
            install_cmd "pipx"
        fi
        echo -e "${YELLOW}📦 Installing jupyter via pipx (with CLI apps)...${NC}"
        if [[ "$OS_TYPE" == "linux" ]]; then
            pipx install jupyter --include-deps
        elif [[ "$OS_TYPE" == "macos" ]]; then
            pipx install jupyter --include-deps
        fi
        ;;
    *)
        echo -e "${RED}⚠️ No installation method defined for '$cmd'${NC}"
        ;;
    esac
}

# Add ~/.local/bin to PATH and persist in .bashrc or .zshrc
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo -e "${YELLOW}🔧 Adding ~/.local/bin to PATH...${NC}"
    export PATH="$HOME/.local/bin:$PATH"
    SHELL_NAME=$(basename "$SHELL")
    if [[ "$SHELL_NAME" == "zsh" ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >>~/.zshrc
    else
        echo 'export PATH="$HOME/.local/bin:$PATH"' >>~/.bashrc
    fi
fi

# Run check loop
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${RED}❌ $cmd is not installed.${NC}"

        # Ask user before installation
        read -rp "$(echo -e ${YELLOW}"❓ Do you want to install $cmd? (y/n): "${NC})" response
        if [[ "$response" == "y" || "$response" == "Y" ]]; then
            install_cmd "$cmd"
            hash -r # Refresh shell's lookup

            # Recheck
            if command -v "$cmd" >/dev/null 2>&1; then
                echo -e "${GREEN}✅ $cmd was successfully installed.${NC}"
            else
                echo -e "${RED}⚠️ $cmd is still missing after installation attempt.${NC}"
                MISSING=1
            fi
        else
            echo -e "${RED}⛔ Skipping installation of $cmd. Exiting.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✅ $cmd is available.${NC}"
    fi
done

# Summary
if [[ "$MISSING" -eq 1 ]]; then
    echo -e "${RED}❌ One or more dependencies are still missing. Please fix manually and re-run.${NC}"
    exit 1
else
    echo -e "${GREEN}🎉 All required dependencies are installed!${NC}"
    echo ""
    echo -e "${YELLOW}📦 Versions of installed packages:${NC}"
    echo -e " - python3:  $(python3 --version 2>&1)"
    echo -e " - pip3:     $(pip3 --version 2>&1)"
    echo -e " - pipenv:   $(pipenv --version 2>&1)"
    echo -e " - pyenv:   $(pyenv --version 2>&1)"
    echo -e " - pipx:     $(pipx --version 2>&1 || echo 'pipx CLI not found')"
    echo -e " - jupyter:  $(jupyter --version 2>&1 || echo 'jupyter CLI not found')"
fi

# --------------------------------------------------
# 🔹 FEATURE 2: Python Version Selection & Validation
# --------------------------------------------------

CURRENT_PYTHON=$(python3 --version 2>&1)
echo -e "\n${BLUE}🐍 Current default Python: $CURRENT_PYTHON${NC}"

# -----------------------------------------------
# 🔍 Show all installed Python versions (pyenv)
# -----------------------------------------------
if command -v pyenv >/dev/null 2>&1; then
    echo -e "\n${BLUE}📌 Available Python versions via pyenv:${NC}"
    pyenv versions | sed 's/^/   - /'
    echo ""
else
    echo -e "\n${YELLOW}⚠️  pyenv not found. Cannot list installed Python versions.${NC}"
fi

CHANGE_VER=$(read_input "💬 Do you want to use a different Python version? (y/N) [auto-continue in 20s]: " "n")

if [[ "$CHANGE_VER" == "y" ]]; then
    USER_INPUT=$(read_input "🔢 Enter Python version (e.g., 3.12.11 or python3.11 or full path) [auto-continue in 20s]: " "")
    USER_INPUT=$(echo "$USER_INPUT" | xargs) # trim spaces

    # 🧪 Validate input Python version using pyenv
    if ! pyenv versions --bare | grep -q "^$USER_INPUT$"; then
        echo -e "${RED}❌ Python version '$USER_INPUT' is not installed via pyenv.${NC}"
        echo -e "${YELLOW}📦 Attempting to install it...${NC}"
        pyenv install "$USER_INPUT" || {
            echo -e "${RED}❌ Failed to install Python version $USER_INPUT via pyenv.${NC}"
            exit 1
        }
        pyenv rehash
    else
        echo -e "${GREEN}✅ Python version '$USER_INPUT' is available in pyenv.${NC}"
    fi

    if [[ -z "$USER_INPUT" ]]; then
        echo -e "${RED}❌ No input provided. Using default Python: $CURRENT_PYTHON${NC}"
        CUSTOM_PYTHON="python3"
    elif command -v "$USER_INPUT" >/dev/null 2>&1; then
        CUSTOM_PYTHON="$USER_INPUT"
        CUSTOM_VER=$($CUSTOM_PYTHON --version 2>&1)
        echo -e "${GREEN}✅ Found Python: $CUSTOM_VER${NC}"

    else
        # Case 2: Extract major.minor version from input (e.g., 3.12 from 3.12.11)
        MAJOR_MINOR=$(echo "$USER_INPUT" | grep -Eo '^[0-9]+\.[0-9]+')

        if [[ -z "$MAJOR_MINOR" ]]; then
            echo -e "${RED}❌ Invalid version format. Use something like 3.12.11 or 3.11${NC}"
            exit 1
        fi

        # Attempt to match version to Python binary in /usr/bin
        MATCHED_PATH="/usr/bin/python$MAJOR_MINOR"
        MATCHED_PATH=$(command -v "python$MAJOR_MINOR")

        if [[ -n "$MATCHED_PATH" && -x "$MATCHED_PATH" ]]; then
            CUSTOM_PYTHON="$MATCHED_PATH"
            CUSTOM_VER=$($CUSTOM_PYTHON --version 2>&1)
            echo -e "${GREEN}✅ Using Python: $CUSTOM_PYTHON ($CUSTOM_VER)${NC}"
        else
            echo -e "${YELLOW}🔍 Python $USER_INPUT not found. Trying to install it via pyenv...${NC}"
            if command -v pyenv >/dev/null 2>&1; then
                pyenv install -s "$USER_INPUT"
                pyenv rehash
                MATCHED_PATH=$(pyenv which python || true)

                if [[ -x "$MATCHED_PATH" ]]; then
                    CUSTOM_PYTHON="$MATCHED_PATH"
                    CUSTOM_VER=$($CUSTOM_PYTHON --version 2>&1)
                    echo -e "${GREEN}✅ Successfully installed and using: $CUSTOM_PYTHON ($CUSTOM_VER)${NC}"
                else
                    echo -e "${RED}❌ Installation failed or Python binary still not found for '$USER_INPUT'.${NC}"
                    exit 1
                fi
            else
                echo -e "${RED}❌ pyenv is not available to install Python version '$USER_INPUT'.${NC}"
                exit 1
            fi
        fi
    fi
else
    CUSTOM_PYTHON="python3"
    echo -e "${GREEN}✅ Keeping current Python: $CURRENT_PYTHON${NC}"
fi

# --------------------------------------------------
# 🔹 FEATURE 3: Check for Existing Global Environments (with loop)
# --------------------------------------------------

# GLOBAL_VENV_DIR="$HOME/.local/share/virtualenvs"
# Set default global venv dir, allow override via env var
GLOBAL_VENV_DIR="${PIPENV_VENV_GLOBAL_DIR:-$HOME/.local/share/virtualenvs}"

# Ensure the directory exists and is writable
if [[ ! -d "$GLOBAL_VENV_DIR" ]]; then
    mkdir -p "$GLOBAL_VENV_DIR" || {
        echo -e "${RED}❌ Failed to create global virtualenv directory: $GLOBAL_VENV_DIR${NC}"
        exit 1
    }
fi

if [[ ! -w "$GLOBAL_VENV_DIR" ]]; then
    echo -e "${RED}❌ Global virtualenv directory is not writable: $GLOBAL_VENV_DIR${NC}"
    exit 1
fi

PROJECT_DIR=$(pwd)
RAW_PROJECT_NAME=$(basename "$PROJECT_DIR")
PROJECT_NAME=$(echo "$RAW_PROJECT_NAME" | tr -cd '[:alnum:]-_')

while true; do
    EXISTING_ENVS=$(ls "$GLOBAL_VENV_DIR" 2>/dev/null | grep -i "^$PROJECT_NAME-" || true)

    if [[ -z "$EXISTING_ENVS" ]]; then
        echo -e "${GREEN}✅ No existing global environments found for this project.${NC}"
        break
    fi

    echo -e "\n${YELLOW}⚠️  Found existing virtual environments for project '${PROJECT_NAME}':${NC}"
    echo "$EXISTING_ENVS" | nl

    echo -e "\n${BLUE}💬 What would you like to do?${NC}"
    echo "  [k] → Keep all"
    echo "  [a] → Delete all"
    echo "  [s] → Select and delete"

    ACTION=$(read_input "Your choice (k/a/s): " "k")

    if [[ "$ACTION" == "a" ]]; then
        echo -e "${BLUE}🧹 Deleting all environments...${NC}"
        for ENV in $EXISTING_ENVS; do
            rm -rf "$GLOBAL_VENV_DIR/$ENV"
            echo -e "${GREEN}✅ Deleted: $ENV${NC}"
        done

    elif [[ "$ACTION" == "s" ]]; then
        TO_DELETE=$(read_input "🧾 Enter environment numbers (comma-separated) to delete (e.g., 1,3) [auto-continue in 20s]: " "")
        if [[ -z "$TO_DELETE" ]]; then
            echo -e "${YELLOW}⏭️ No input provided. Keeping all environments.${NC}"
            break
        fi
        IFS=',' read -ra INDICES <<<"$TO_DELETE"
        COUNTER=0
        while IFS= read -r ENV; do
            ((COUNTER++))
            for IDX in "${INDICES[@]}"; do
                if [[ "$COUNTER" -eq "$IDX" ]]; then
                    rm -rf "$GLOBAL_VENV_DIR/$ENV"
                    echo -e "${GREEN}✅ Deleted: $ENV${NC}"
                fi
            done
        done <<<"$EXISTING_ENVS"

    else
        echo -e "${GREEN}✅ Keeping all existing environments.${NC}"
        break
    fi
done

# --------------------------------------------------
# 🔹 FEATURE 4: Create Local .venv Environment
# --------------------------------------------------

# Use selected Python or fallback to default
SELECTED_PYTHON=${CUSTOM_PYTHON:-python3}
export PIPENV_PYTHON="$SELECTED_PYTHON"

echo -e "\n${BLUE}📦 Creating Pipenv environment locally in .venv using Python: $SELECTED_PYTHON${NC}"

# Force pipenv to create environment in ./.venv folder
PIPENV_VENV_IN_PROJECT=1 pipenv --python "$(pyenv prefix $USER_INPUT)/bin/python" || {
    echo -e "${RED}❌ Failed to create Pipenv environment.${NC}"
    exit 1
}

# Set environment path and name
VENV_PATH="$(pwd)/.venv"
ENV_NAME=".venv"

if [[ -d "$VENV_PATH" ]]; then
    echo -e "${GREEN}✅ Environment created successfully!${NC}"
    echo -e "${YELLOW}📍 Environment name: ${ENV_NAME}${NC}"
    echo -e "${BLUE}📁 Location: $VENV_PATH${NC}"
else
    echo -e "${RED}❌ Failed to create the environment.${NC}"
    exit 1
fi

# --------------------------------------------------
# 🔹 FEATURE 5: Post-Creation Actions
# --------------------------------------------------

echo -e "\n${BLUE}💬 What would you like to do with this environment?${NC}"
echo "  [a] → Activate it"
echo "  [d] → Delete it"
echo "  [s] → Save it to global envs (~/.local/share/virtualenvs)"
echo "  [k] → Keep it as is (do nothing)"

POST_ACTION=$(read_input "Your choice (a/d/s/k) [auto-continue in 20s]: " "k")

if [[ "$POST_ACTION" == "a" ]]; then
    echo -e "${BLUE}🚀 Activating environment...${NC}"
    pipenv shell

elif [[ "$POST_ACTION" == "d" ]]; then
    echo -e "${YELLOW}🗑️ Deleting environment...${NC}"
    pipenv --rm
    rm -rf .venv Pipfile Pipfile.lock
    echo -e "${GREEN}✅ Environment deleted.${NC}"
    echo ""

elif [[ "$POST_ACTION" == "s" ]]; then
    echo -e "${BLUE}📁 Saving environment to global directory...${NC}"

    # Determine a sed inline option based on OS_TYPE
    if [[ "$OS_TYPE" == "macos" ]]; then
        SED_INPLACE=("sed" "-i" "")
    else
        SED_INPLACE=("sed" "-i")
    fi

    GLOBAL_VENV_DIR="$HOME/.local/share/virtualenvs"

    # Avoid name collision in global dir
    while true; do
        RANDOM_SUFFIX=$(python3 -c "import random, string; print(''.join(random.choices(string.ascii_lowercase + string.digits, k=6)))")
        ENV_NAME="${PROJECT_NAME}-${RANDOM_SUFFIX}"
        TARGET_GLOBAL_PATH="$GLOBAL_VENV_DIR/$ENV_NAME"
        [[ ! -e "$TARGET_GLOBAL_PATH" ]] && break
    done

    mkdir -p "$GLOBAL_VENV_DIR"

    if [[ ! -d ".venv" ]]; then
        echo -e "${RED}❌ .venv not found. Cannot move environment.${NC}"
        exit 1
    fi

    # Save old venv path
    OLD_VENV_PATH="$(realpath .venv)"

    mv .venv "$TARGET_GLOBAL_PATH"

    echo -e "${GREEN}✅ Environment moved to global location:${NC}"
    echo -e "${YELLOW}📍 Name: $ENV_NAME${NC}"
    echo -e "${BLUE}📁 Location: $TARGET_GLOBAL_PATH${NC}"

    echo -e "${BLUE}🔧 Fixing activate script path...${NC}"
    ACTIVATE_SCRIPT="$TARGET_GLOBAL_PATH/bin/activate"
    "${SED_INPLACE[@]}" "s|^VIRTUAL_ENV=.*|VIRTUAL_ENV=$TARGET_GLOBAL_PATH|" "$ACTIVATE_SCRIPT"

    echo -e "${BLUE}🔧 Updating shebangs in bin/ scripts...${NC}"
    BIN_DIR="$TARGET_GLOBAL_PATH/bin"
    for file in "$BIN_DIR"/*; do
        if head -n 1 "$file" | grep -q "^#\!$OLD_VENV_PATH"; then
            echo "  Fixing: $(basename "$file")"
            "${SED_INPLACE[@]}" "1s|^#\!$OLD_VENV_PATH.*|#!$TARGET_GLOBAL_PATH/bin/python|" "$file"
        fi
    done

    echo -e "${BLUE}🔁 Rebinding pipenv to use moved environment...${NC}"

    # Setup a Pipfile if missing
    [[ ! -f "Pipfile" ]] && pipenv --python "$(realpath "$TARGET_GLOBAL_PATH/bin/python")" >/dev/null 2>&1

    # Overwrite PIPENV_ACTIVE environment
    export PIPENV_IGNORE_VIRTUALENVS=1
    export PIPENV_PYTHON="$(realpath "$TARGET_GLOBAL_PATH/bin/python")"

    echo -e "${GREEN}✅ Pipenv now bound to existing global env. You can activate it with:${NC}"
    echo -e "${BLUE}   pipenv shell${NC}"
    echo -e "${YELLOW}💡 Note: You can also activate it with: source $TARGET_GLOBAL_PATH/bin/activate${NC}"
    echo ""
else
    echo -e "${GREEN}✅ Keeping environment as local .venv. You can activate with: pipenv shell${NC}"
fi

# --------------------------------------------------
# 🔹 FEATURE 6: Install Dependencies (Interactive)
# --------------------------------------------------

INSTALL_CHOICE=$(read_input "💬 Do you want to install dependencies from requirements.txt if it exists? (y/N) [auto-continue in 20s]: " "n")
if [[ "$INSTALL_CHOICE" != "y" ]]; then
    echo -e "${YELLOW}⏭️ Skipping dependency installation.${NC}"
    echo ""
else
    echo -e "\n${BLUE}📦 Preparing to install dependencies...${NC}"

    # Ensure we're in the project directory
    cd "$PROJECT_DIR" || {
        echo -e "${RED}❌ Project directory not found: $PROJECT_DIR${NC}"
        exit 1
    }

    # Use global environment if it was moved in Feature 5, otherwise use local .venv
    if [[ "$POST_ACTION" == "s" && -n "$TARGET_GLOBAL_PATH" && -d "$TARGET_GLOBAL_PATH" ]]; then
        VENV_PATH="$TARGET_GLOBAL_PATH"
        PYTHON_PATH="$(realpath "$VENV_PATH/bin/python")"
        export PIPENV_PYTHON="$PYTHON_PATH"
        export PIPENV_IGNORE_VIRTUALENVS=1
        export PIPENV_CUSTOM_VENV_NAME="$ENV_NAME"
        echo -e "${BLUE}📍 Using global environment: $VENV_PATH${NC}"
        echo ""
    else
        VENV_PATH="$(pwd)/.venv"
        PYTHON_PATH="$SELECTED_PYTHON"
        export PIPENV_VENV_IN_PROJECT=1
        export PIPENV_PYTHON="$PYTHON_PATH"
        echo -e "${BLUE}📍 Using local environment: $VENV_PATH${NC}"
        echo ""
    fi

    # Remove Pipfile/Pipfile.lock only if they are missing or mismatched
    if [[ ! -f "Pipfile" || "$(grep "$PIPENV_PYTHON" Pipfile)" == "" ]]; then
        rm -f Pipfile Pipfile.lock
        pipenv --python "$PIPENV_PYTHON" >/dev/null 2>&1 || {
            echo -e "${RED}❌ Failed to initialize Pipfile for environment.${NC}"
            exit 1
        }
    fi

    if [[ -f "requirements.txt" ]]; then
        echo -e "${GREEN}📄 Found requirements.txt with the following packages:${NC}"
        cat requirements.txt
        echo ""
        echo
        pipenv install -r requirements.txt --skip-lock || {
            echo -e "${RED}❌ Failed to install dependencies from requirements.txt.${NC}"
            exit 1
        }
    else
        echo -e "${YELLOW}📄 No requirements.txt found. The following packages will be installed:${NC}"
        echo -e "   pandas\n   numpy\n   openpyxl\n   matplotlib\n   seaborn\n   requests\n   ipython\n"
        pipenv install pandas numpy openpyxl matplotlib seaborn requests ipython --skip-lock || {
            echo -e "${RED}❌ Failed to install default dependencies.${NC}"
            exit 1
        }

        echo -e "${BLUE}📝 Generating requirements.txt from installed packages...${NC}"
        pipenv run pip freeze >requirements.txt
        echo -e "${GREEN}✅ requirements.txt created.${NC}"
    fi

    echo -e "${BLUE}🔒 Locking environment...${NC}"
    pipenv lock || {
        echo -e "${RED}❌ Failed to lock the Pipenv environment.${NC}"
        exit 1
    }

    echo -e "${GREEN}✅ Dependencies installed and environment locked.${NC}"
    echo ""
fi

# --------------------------------------------------
# 🔹 FEATURE 7: Register Jupyter Kernel (Optional)
# --------------------------------------------------

REGISTER_CHOICE=$(read_input "💬 Will you use Jupyter notebooks outside PyCharm (e.g., JupyterLab, VS Code) [Registering Jupyter kernel]? (y/N) [auto-continue in 20s]: " "n")

if [[ "$REGISTER_CHOICE" != "y" ]]; then
    echo -e "${YELLOW}⏭️ Skipping kernel registration.${NC}"
    echo ""
else
    # ✅ Use saved ENV_NAME from Feature 5 or create fallback
    if [[ -z "$ENV_NAME" ]]; then
        ENV_NAME="custom-env-$(date +%s)"
    fi

    # 🔠 Format kernel name (all lowercase)
    KERNEL_NAME=$(basename "$ENV_NAME" | tr '[:upper:]' '[:lower:]')

    # ✅ Resolve virtual environment path
    if [[ -n "$TARGET_GLOBAL_PATH" && -d "$TARGET_GLOBAL_PATH" ]]; then
        VENV_PATH="$TARGET_GLOBAL_PATH"
    else
        VENV_PATH="$(pwd)/.venv"
    fi

    echo -e "${BLUE}📍 Using environment at: $VENV_PATH${NC}"
    echo -e "${BLUE}🧠 Registering Jupyter kernel: $KERNEL_NAME${NC}"

    # ✅ Ensure environment is activated by setting appropriate variables
    export VIRTUAL_ENV="$VENV_PATH"
    export PATH="$VENV_PATH/bin:$PATH"

    # ✅ Ensure ipykernel is installed inside the virtualenv
    if ! "$VENV_PATH/bin/python" -c "import ipykernel" 2>/dev/null; then
        echo -e "${YELLOW}📦 ipykernel not found. Installing in virtualenv...${NC}"
        if ! "$VENV_PATH/bin/pip" install ipykernel; then
            echo -e "${RED}❌ Failed to install ipykernel.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✅ ipykernel already installed in environment.${NC}"
    fi

    # 🚫 Check if a kernel with same name already exists
    if jupyter kernelspec list --json 2>/dev/null | grep -q "\"$KERNEL_NAME\""; then
        echo -e "${RED}⚠️ A Jupyter kernel named \"$KERNEL_NAME\" already exists.${NC}"
        echo -e "    👉 You can remove it using: ${YELLOW}jupyter kernelspec uninstall $KERNEL_NAME${NC}"
        exit 1
    fi

    # ✅ Register the kernel using the virtualenv's python binary
    if "$VENV_PATH/bin/python" -m ipykernel install --user --name "$KERNEL_NAME" --display-name "$ENV_NAME"; then
        echo ""
        echo -e "${GREEN}✅ Kernel registered as '$ENV_NAME'.${NC}"
        echo -e "${BLUE}💡 To activate it, open JupyterLab or VS Code and select the '$ENV_NAME' kernel.${NC}"
        echo ""
    else
        echo -e "${RED}❌ Failed to register Jupyter kernel.${NC}"
        exit 1
    fi
fi

# --------------------------------------------------
# 🔹 FEATURE 8: Activate Newly Created Environment
# --------------------------------------------------

ACTIVATE_CHOICE=$(read_input "💬 Do you want to activate the newly created environment now? (y/N) [auto-continue in 20s]: " "n")

if [[ "$ACTIVATE_CHOICE" == "y" ]]; then
    echo -e "${BLUE}🚀 Activating the newly created Pipenv environment...${NC}"

    # Determine environment path
    if [[ -n "$TARGET_GLOBAL_PATH" && -d "$TARGET_GLOBAL_PATH" ]]; then
        VENV_PATH="$TARGET_GLOBAL_PATH"
        ENV_SOURCE="global"
    else
        VENV_PATH="$(pwd)/.venv"
        ENV_SOURCE="local"
    fi

    ACTIVATE_SCRIPT="$VENV_PATH/bin/activate"

    if [[ ! -f "$ACTIVATE_SCRIPT" ]]; then
        echo -e "${RED}❌ Activation script not found at: $ACTIVATE_SCRIPT${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Found activation script at: $ACTIVATE_SCRIPT${NC}"
    echo -e "${BLUE}🔄 Entering the $ENV_SOURCE virtual environment...${NC}"

    # Launch a new interactive bash shell with the venv activated
    bash --rcfile <(echo "source '$ACTIVATE_SCRIPT'") -i

else
    echo -e "${YELLOW}⏭️ Skipping environment activation. You can activate it later with:${NC}"
    echo ""
    if [[ -n "$TARGET_GLOBAL_PATH" && -d "$TARGET_GLOBAL_PATH" ]]; then
        echo -e "${BLUE}   source $TARGET_GLOBAL_PATH/bin/activate${NC}"
    else
        echo -e "${BLUE}   pipenv shell${NC}"
    fi
fi
