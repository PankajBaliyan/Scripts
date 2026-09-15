# Create Venv Setup and Usage

This guide covers both installing the helper script as a command and using the environment creation script.

## 1) Install the helper script

```bash
# Check target folder
cd ~/bin

# If not exist, create new one
mkdir -p ~/bin

# Copy the script into the bin folder
cp pipenv_temp_env.sh ~/bin

# Give executable permission
chmod +x ~/bin/create-venv-here.sh
```

## 2) Create an alias

For Zsh:

```bash
echo 'alias create-venv-here="/Users/pankajkumar/bin/create-venv-here.sh"' >> ~/.zshrc
source ~/.zshrc
```

Now you can run:

```bash
create-venv-here
```

## 3) How to use the Python environment setup script

This Bash script simplifies setting up and managing Python virtual environments using Pipenv. Put `pipenv_temp_env.sh` in the same directory as your project and run it to create a temporary environment.

```bash
chmod +x pipenv_temp_env.sh && ./pipenv_temp_env.sh
```

### Prerequisites

- Ensure you have `pipenv`, `jupyter`, and `python3` installed on your system.
- For macOS/Linux, you can install them using package managers like Homebrew or apt.
- Verify installations with:

```bash
pipenv --version
jupyter --version
python3 --version
```

### Run the script

```bash
cd /path/to/your/project
./pipenv_temp_env.sh
```

The script will guide you through the setup with interactive prompts.

### Key features

- Dependency check for required tools
- Python version selection and validation
- Environment detection and cleanup for existing project environments
- Local `.venv` creation with Pipenv
- Post-creation options:
  - Activate the environment
  - Delete the environment
  - Move it to a global directory in `~/.local/share/virtualenvs`
  - Keep it as-is
- Dependency installation from `requirements.txt` or a default set
- Jupyter kernel registration for VS Code / JupyterLab
- Environment activation instructions for later use

### Example workflow

```bash
./pipenv_temp_env.sh
```

Then:

1. Keep the default Python version or choose another version such as `3.11`
2. Keep, delete, or select existing environments if found
3. Choose `a` to activate, `d` to delete, `s` to save globally, or `k` to keep
4. Optionally install dependencies and register a Jupyter kernel
5. Activate the environment with `pipenv shell` or use the generated activation script

### Useful notes

- Ensure your project directory is writable and has no conflicting `.venv` or `Pipfile` from previous setups.
- Check the color-coded output for errors or warnings.
- To see available Python versions:

```bash
ls /usr/bin/python3.*
```

- To remove a Jupyter kernel:

```bash
jupyter kernelspec uninstall <kernel-name>
```

### Support

For issues or suggestions, check the repository documentation and the script itself. The script is designed for macOS and Linux.

Enjoy a streamlined Python setup process.
