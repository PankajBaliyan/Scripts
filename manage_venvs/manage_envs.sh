#!/usr/bin/env bash

set -eu

VENV_DIR="${VENV_DIR:-${PIPENV_VENV_GLOBAL_DIR:-$HOME/.local/share/virtualenvs}}"
mkdir -p "$VENV_DIR"

usage() {
    cat <<'EOF'
Manage Python virtual environments.

Usage:
  ./manage_envs.sh                 # interactive menu
  ./manage_envs.sh list-local
  ./manage_envs.sh list-global
  ./manage_envs.sh create-current
  ./manage_envs.sh create <env-name>
  ./manage_envs.sh activate <env-name>
  ./manage_envs.sh delete <env-name>
  ./manage_envs.sh help

Examples:
  ./manage_envs.sh list-local
  ./manage_envs.sh list-global
  ./manage_envs.sh create-current
  ./manage_envs.sh create myproject
  ./manage_envs.sh activate myproject
  ./manage_envs.sh delete myproject

Notes:
  - Global environments are stored in: $VENV_DIR
  - Local envs are created in the current working directory as .venv
EOF
}

list_local_envs() {
    local envs=()
    local item

    for item in "$PWD"/*; do
        if [[ -d "$item" && ( "$item" == "$PWD/.venv" || "$item" == "$PWD/venv" || "$item" == *"venv"* ) ]]; then
            envs+=("$(basename "$item")")
        fi
    done

    if [[ ${#envs[@]} -eq 0 ]]; then
        echo "No virtual environment found in current directory: $PWD"
        return 0
    fi

    echo "Local virtual environments in $PWD:"
    printf ' - %s\n' "${envs[@]}"
}

list_global_envs() {
    if [[ ! -d "$VENV_DIR" ]]; then
        echo "No global virtual environments found in $VENV_DIR"
        return 0
    fi

    shopt -s nullglob
    local envs=("$VENV_DIR"/*)
    shopt -u nullglob

    if [[ ${#envs[@]} -eq 0 ]]; then
        echo "No global virtual environments found in $VENV_DIR"
        return 0
    fi

    local kernel_info=""
    local kernel_json=""
    local kernel_name=""
    local python_ver=""
    local status="No"
    local count=0
    local env_path
    local size_kb=""
    local env_size=""

    echo "Checking Python virtualenvs in: $VENV_DIR"
    echo "---------------------------------------------------------"
    printf '%-4s | %-35s | %-10s | %-10s | %-12s\n' "No." "VirtualEnv" "Python" "Kernel" "Size"
    echo "---------------------------------------------------------"

    for env_path in "${envs[@]}"; do
        if [[ ! -d "$env_path/bin" ]]; then
            continue
        fi

        ((count++))
        kernel_name="$(basename "$env_path")"
        status="No"
        env_size="0B"

        if [[ -x "$env_path/bin/python" ]]; then
            python_ver=$("$env_path/bin/python" --version 2>&1 | sed 's/^Python //')
        else
            python_ver="unknown"
        fi

        if command -v du >/dev/null 2>&1; then
            size_kb=$(du -sk "$env_path" 2>/dev/null | awk '{print $1}')
            if [[ -n "$size_kb" ]]; then
                if (( size_kb < 1024 )); then
                    env_size="${size_kb}K"
                elif (( size_kb < 1048576 )); then
                    env_size="$(awk -v s="$size_kb" 'BEGIN { printf "%.1fM", s/1024 }')"
                else
                    env_size="$(awk -v s="$size_kb" 'BEGIN { printf "%.1fG", s/1048576 }')"
                fi
            fi
        fi

        if [[ -n "$kernel_json" ]]; then
            if echo "$kernel_json" | grep -qF "\"$kernel_name\""; then
                status="Yes"
            fi
        fi

        if [[ "$status" == "No" ]]; then
            for kernel_dir in "$HOME/.local/share/jupyter/kernels" "$HOME/Library/Jupyter/kernels"; do
                if [[ -d "$kernel_dir" ]]; then
                    for k in "$kernel_dir"/*; do
                        if [[ -f "$k/kernel.json" ]]; then
                            if grep -qF "\"$env_path/bin/python\"" "$k/kernel.json" 2>/dev/null; then
                                status="Yes"
                                break 2
                            fi
                        fi
                    done
                fi
            done
        fi

        printf '%-4s | %-35s | %-10s | %-10s | %-12s\n' "$count" "$kernel_name" "$python_ver" "$status" "$env_size"
    done

    echo "---------------------------------------------------------"
}

create_global_env() {
    local env_name="${1:-}"
    if [[ -z "$env_name" ]]; then
        echo "Error: please provide an environment name." >&2
        usage >&2
        exit 1
    fi

    local target="$VENV_DIR/$env_name"
    if [[ -d "$target" ]]; then
        echo "Environment '$env_name' already exists at $target"
        exit 1
    fi

    python3 -m venv "$target"
    echo "Created virtual environment: $target"
    echo "Activate it with: source $target/bin/activate"
}

activate_env() {
    local env_name="${1:-}"
    if [[ -z "$env_name" ]]; then
        echo "Error: please provide an environment name." >&2
        usage >&2
        exit 1
    fi

    local target="$VENV_DIR/$env_name"
    if [[ ! -d "$target/bin" ]]; then
        echo "Environment '$env_name' does not exist in $VENV_DIR" >&2
        exit 1
    fi

    echo "source \"$target/bin/activate\""
}

delete_env() {
    local env_name="${1:-}"
    if [[ -z "$env_name" ]]; then
        echo "Error: please provide an environment name." >&2
        usage >&2
        exit 1
    fi

    local target="$VENV_DIR/$env_name"
    if [[ ! -d "$target" ]]; then
        echo "Environment '$env_name' does not exist." >&2
        exit 1
    fi

    printf "Delete environment '%s'? [y/N]: " "$env_name"
    read -r answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        rm -rf "$target"
        echo "Deleted: $target"
    else
        echo "Cancelled."
    fi
}

create_current_local_env() {
    local target="$PWD/.venv"

    if [[ -d "$target" ]]; then
        echo "A local .venv already exists in this directory: $target"
        read -rp "Do you want to delete it and recreate? [y/N]: " answer
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            echo "Keeping the existing environment."
            echo "Activate it with: source \"$target/bin/activate\""
            return 0
        fi
        rm -rf "$target"
    fi

    echo "Creating local virtual environment in: $target"
    python3 -m venv "$target"

    echo "Activating environment..."
    # shellcheck disable=SC1091
    source "$target/bin/activate"

    echo "Environment is active: $VIRTUAL_ENV"
    echo "You can install packages now."

    echo "Deleting the local environment after activation..."
    deactivate >/dev/null 2>&1 || true
    rm -rf "$target"
    echo "Deleted local environment: $target"
}

show_menu() {
    cat <<'EOF'
========================================
Python Virtual Environment Manager
========================================
1) List environments in current directory
2) List environments in global directory
3) Create venv in current directory, activate it, then delete it
4) Exit
========================================
EOF
}

interactive_menu() {
    while true; do
        show_menu
        read -rp "Choose an option [1-4]: " choice

        case "$choice" in
            1)
                list_local_envs
                ;;
            2)
                list_global_envs
                ;;
            3)
                create_current_local_env
                ;;
            4)
                echo "Bye!"
                exit 0
                ;;
            *)
                echo "Invalid option. Please choose 1, 2, 3 or 4."
                ;;
        esac

        echo
        read -rp "Press Enter to continue..." _
    done
}

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 is required but not installed." >&2
    exit 1
fi

case "${1:-}" in
    "")
        interactive_menu
        ;;
    list-local)
        list_local_envs
        ;;
    list-global)
        list_global_envs
        ;;
    create-current)
        create_current_local_env
        ;;
    create)
        create_global_env "${2:-}"
        ;;
    activate)
        activate_env "${2:-}"
        ;;
    delete|remove)
        delete_env "${2:-}"
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        echo "Unknown command: ${1:-}"
        usage >&2
        exit 1
        ;;
 esac
