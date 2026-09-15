# Python Environment Setup Script

A Bash utility for automating the setup, management, and troubleshooting of Python environments using Pipenv and pyenv. This script helps you create isolated project environments, install dependencies, manage Python versions, register Jupyter kernels, and fix common environment problems on macOS and Linux.

## What this script does

This script automates the setup, management, and troubleshooting of Python environments using Pipenv and pyenv. It helps you:

- check whether required tools are installed: `python3`, `pip3`, `pipenv`, `pyenv`, `pipx`, and `jupyter`
- install missing tools automatically with Homebrew or `apt`
- detect the operating system and adjust commands for macOS or Linux
- validate the current project folder name and warn if it contains spaces or apostrophes
- switch to a different Python version using `pyenv`
- create a Pipenv environment in the project (`.venv` by default)
- detect old project environments and let you keep, remove, or selectively delete them
- support local and global environment handling
- install dependencies from `requirements.txt` or a default package set
- generate a `requirements.txt` file if it is missing
- register the environment as a Jupyter kernel for JupyterLab or VS Code
- activate the environment when needed
- repair and troubleshoot broken Python/Pipenv setup

It includes these features:

- Dependency validation and auto-installation
- Python version selection and validation
- Pipenv environment creation and reuse
- Local/global virtual environment support
- Interactive environment cleanup and management
- Jupyter kernel registration
- Environment activation support
- Colored terminal output and guided prompts
- Cross-platform handling for macOS and Linux
- Optional install as a reusable command in `~/bin`

## Prerequisites

The script expects the following tools to be available or installable:

- `python3`
- `pip3`
- `pipenv`
- `pyenv`
- `pipx`
- `jupyter`

### Install on macOS

```bash
brew install python pipx pyenv pipenv
pipx install jupyter --include-deps
```

### Install on Ubuntu/Debian

```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv build-essential curl git
python3 -m pip install --user pipx
~/.local/bin/pipx install pipenv
~/.local/bin/pipx install jupyter --include-deps
```

## Installation

1. Clone the repository:

```bash
git clone https://github.com/PankajBaliyan/Scripts.git
cd Scripts/manage_venvs
```

2. Make the script executable:

```bash
chmod +x pipenv_temp_env.sh
```

3. Run it:

```bash
./pipenv_temp_env.sh
```

## Usage

### Quick start

```bash
chmod +x pipenv_temp_env.sh && ./pipenv_temp_env.sh
```

### Step-by-step

1. Ensure you have the required tools installed:

   - `pipenv`
   - `jupyter`
   - `python3`
   - `pip3`
   - `pyenv`
   - `pipx`

2. Save the script as `pipenv_temp_env.sh` in your project directory.

3. Run the script:

```bash
cd /path/to/your/project
chmod +x pipenv_temp_env.sh
./pipenv_temp_env.sh
```

4. Follow the interactive prompts to:
   - check dependencies
   - choose a Python version
   - manage existing environments
   - create a local `.venv` environment
   - install dependencies from `requirements.txt` or default packages
   - optionally register a Jupyter kernel
   - activate the environment or keep it as-is

### Key features and interactions

- Dependency Check: verifies required tools and alerts you if any are missing.
- Python Version Selection: shows the default Python version and lets you choose a specific version such as `3.12` or a full path like `/usr/bin/python3.11`.
- Environment Management: detects existing virtual environments for the project and allows you to keep, delete, or selectively remove them.
- Environment Creation: creates a local `.venv` environment using the selected Python version.
- Post-Creation Options:
  - Activate the environment (`a`)
  - Delete it (`d`)
  - Move it to a global directory (`s`) at `~/.local/share/virtualenvs`
  - Keep it as is (`k`)
- Dependency Installation: installs packages from `requirements.txt` or a default set such as `pandas`, `numpy`, `openpyxl`, `matplotlib`, `seaborn`, `requests`, and `ipython`, and generates `requirements.txt` if needed.
- Jupyter Kernel Registration: optionally registers the environment as a Jupyter kernel for JupyterLab or VS Code.
- Environment Activation: offers immediate activation or instructions for later activation.

### Example workflow

```bash
./pipenv_temp_env.sh
```

Then:

- press Enter to keep the default Python version, or type `y` to choose another version
- choose to keep or manage existing environments if detected
- select `a` to activate the new environment or `s` to save it globally
- choose `y` to install dependencies and `y` to register a Jupyter kernel if needed
- activate the environment with `pipenv shell`, `source .venv/bin/activate`, or `source ~/.local/share/virtualenvs/<env-name>/bin/activate`

### Tips

- Ensure your project directory is writable and has no conflicting `.venv` or `Pipfile` from previous setups.
- If you encounter issues, check the color-coded output for errors (red) or warnings (yellow).
- Use `ls /usr/bin/python3.*` to see available Python versions if needed.
- To remove a Jupyter kernel, run `jupyter kernelspec uninstall <kernel-name>`.
- If your project folder contains spaces or apostrophes, the script will warn you to rename it.

### Testing

You can run the internal test suite by setting:

```bash
TEST_MODE=true ./pipenv_temp_env.sh
```

This is mainly useful for validating the script's dependency-check logic.

## Optional command installation

You can install this script as a reusable shell command:

```bash
./pipenv_temp_env.sh --install-bin
```

This copies the script to `~/bin` and creates an alias:

```bash
alias create-venv-here="/Users/your-user/bin/create-venv-here.sh"
```

You can then run it from any project folder.

## Example output

```bash
🔍 Checking required dependencies for environment setup...
✅ python3 is available.
✅ pip3 is available.
✅ pipenv is available.
✅ pyenv is available.
✅ pipx is available.
✅ jupyter is available.

🐍 Current default Python: Python 3.12.6
💬 Do you want to use a different Python version? (y/N): y
🔢 Enter Python version (e.g., 3.12.11 or python3.11): 3.12
✅ Found Python: /usr/bin/python3.12 (Python 3.12.6)

📦 Creating Pipenv environment locally in .venv using Python: /usr/bin/python3.12
✅ Environment created successfully!
```

## Files created or managed

The script may create or manage:

- `.venv/`
- `Pipfile`
- `Pipfile.lock`
- `requirements.txt`
- Jupyter kernels
- global environment folders in `~/.local/share/virtualenvs`

## Notes

- The script prefers project-local environments for most workflows.
- If you move an environment to the global directory, the script tries to fix activation and script paths automatically.
- If the project folder path contains spaces or apostrophes, the script exits with a warning and asks you to rename the folder.
- It includes a built-in test mode for validating the dependency checks.

## Support

For issues, suggestions, or questions, open an issue on the [GitHub repository](https://github.com/PankajBaliyan/Scripts) or check the local documentation files:

- `how-to-use.txt`
- `global_setup.md`
- `Venv_Commands_README.md`

This script is designed to simplify Python environment setup for development work, data science, automation, and project-based Python workflows.
