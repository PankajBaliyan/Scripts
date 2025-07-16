# Python Environment Setup Script

A Bash script to automate the setup and management of Python virtual environments using Pipenv. This tool simplifies creating, configuring, and activating virtual environments, making it ideal for developers working on Python projects.

## Features

- **Dependency Check**: Verifies required tools (`pipenv`, `jupyter`, `python3`) are installed.
- **Python Version Selection**: Allows choosing a specific Python version or using the system default.
- **Environment Management**: Detects and manages existing virtual environments (keep, delete, or select specific ones to remove).
- **Local/Global Environments**: Creates local `.venv` environments or moves them to a global directory (`~/.local/share/virtualenvs`).
- **Dependency Installation**: Installs packages from `requirements.txt` or a default set (pandas, numpy, etc.) and generates `requirements.txt` if missing.
- **Jupyter Kernel Registration**: Optionally registers the environment as a Jupyter kernel for JupyterLab or VS Code.
- **Environment Activation**: Activates the environment immediately or provides activation instructions.
- **User-Friendly Interface**: Features color-coded output, interactive prompts with timeouts, and robust error handling.
- **Cross-Platform Support**: Works on macOS and Linux with OS-specific adjustments (e.g., `sed` commands).

## Prerequisites

- **Required Tools**:
  - `pipenv`: For virtual environment management.
  - `jupyter`: For notebook support (optional).
  - `python3`: Python 3.x interpreter.
- Install them on:
  - **macOS**: `brew install pipenv jupyter python`
  - **Linux**: `sudo apt install python3-pip python3-venv jupyter`
- A writable project directory.

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/PankajBaliyan/env-management
   cd env-management
   ```
2. Make the script executable:
   ```bash
   chmod +x pipenv_temp_env.sh
   ```

## Usage

1. Navigate to your project directory:
   ```bash
   cd /path/to/your/project
   ```
2. Copy or link the script to your project:
   ```bash
   cp /path/to/python-env-setup/pipenv_temp_env.sh .
   ```
3. Run the script:
   ```bash
   ./pipenv_temp_env.sh
   ```
4. Follow the interactive prompts to:
   - Select a Python version.
   - Manage existing environments.
   - Create and configure a new environment.
   - Install dependencies.
   - Register a Jupyter kernel (optional).
   - Activate the environment (optional).

For detailed instructions, see [how-to-use.txt](how-to-use.txt).

## Example

```bash
$ ./pipenv_temp_env.sh
🔍 Checking required dependencies...
✅ pipenv is available.
✅ jupyter is available.
✅ python3 is available.

🐍 Current default Python: Python 3.10.12
💬 Do you want to use a different Python version? (y/N) [auto-continue in 20s]: y
🔢 Enter Python version (e.g., 3.12.11 or python3.11): 3.11
✅ Using Python: /usr/bin/python3.11 (Python 3.11.9)

📦 Creating Pipenv environment locally in .venv...
✅ Environment created successfully!
📍 Environment name: .venv
📁 Location: /path/to/your/project/.venv

💬 What would you like to do with this environment? (a/d/s/k): a
🚀 Activating environment...
```

## Contributing

Contributions are welcome! Please:
1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/YourFeature`).
3. Commit changes (`git commit -m 'Add YourFeature'`).
4. Push to the branch (`git push origin feature/YourFeature`).
5. Open a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Support

For issues, suggestions, or questions, open an issue on the [GitHub repository](https://github.com/PankajBaliyan/env-management) or check [how-to-use.txt](how-to-use.txt) for troubleshooting tips.

Happy coding! 🚀