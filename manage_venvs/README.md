# Manage Venvs

This folder contains a simple bash utility to create, list, activate, and remove Python virtual environments.

## Purpose

`manage_envs.sh` helps you manage isolated Python environments without needing to install extra Python tooling. It creates venvs in a central folder under:

```bash
$HOME/.virtualenvs
```

This is useful when you want to keep a reusable set of project environments and avoid cluttering each project folder with local `.venv` directories.

## Files in this folder

- `.gitignore` — ignores common Python and editor files
- `requirements.txt` — optional file for documenting dependencies
- `manage_envs.sh` — bash script to manage virtual environments
- `readme.md` — usage instructions

## Setup

1. Open a terminal in this folder:

```bash
cd /path/to/Scripts/manage_venvs
```

2. Make the script executable:

```bash
chmod +x manage_envs.sh
```

3. Verify Python is installed:

```bash
python3 --version
```

## Usage

### Create a new environment

```bash
./manage_envs.sh create myproject
```

This creates:

```bash
$HOME/.virtualenvs/myproject
```

### List all environments

```bash
./manage_envs.sh list
```

### Print activation command

```bash
./manage_envs.sh activate myproject
```

This prints:

```bash
source "$HOME/.virtualenvs/myproject/bin/activate"
```

Use it like this:

```bash
source "$HOME/.virtualenvs/myproject/bin/activate"
```

### Delete an environment

```bash
./manage_envs.sh delete myproject
```

## Example workflow

```bash
cd /path/to/Scripts/manage_venvs
chmod +x manage_envs.sh
./manage_envs.sh create data_project
./manage_envs.sh list
source "$HOME/.virtualenvs/data_project/bin/activate"
python -m pip install --upgrade pip
pip install requests pandas numpy
```

When you are done:

```bash
deactivate
./manage_envs.sh delete data_project
```

## Notes

- The script uses Python's built-in `venv` module.
- It stores environments in a single location to keep them easy to manage.
- You can adjust the storage directory by exporting `VENV_DIR` before running the script:

```bash
export VENV_DIR="$HOME/my-envs"
./manage_envs.sh list
```

## Good practice

Keep each project environment separate and delete unused ones to avoid clutter.
