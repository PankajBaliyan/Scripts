# 🧪 Virtual Environment Management Commands

Useful commands to manage and inspect Python virtual environments.

---

## 1. List all global virtual environments

```
ls ~/.local/share/virtualenvs/
```

---

## 2. Check the details of your virtual environment

```
source ~/.local/share/virtualenvs/env-manage-main-l2tklu/bin/activate
echo $VIRTUAL_ENV
pip list
deactivate
```

---

## 3. List all environments with more details (Jupyter kernel registered, name, path)

```bash
#!/bin/bash

GLOBAL_VENV_DIR="$HOME/.local/share/virtualenvs"
KERNELS_DIR="$HOME/Library/Jupyter/kernels" # macOS path (Linux: ~/.local/share/jupyter/kernels)

count=1
for venv_path in "$GLOBAL_VENV_DIR"/*; do
    if [[ -d "$venv_path" && -x "$venv_path/bin/python" ]]; then
        name=$(basename "$venv_path")
        python_ver=$("$venv_path/bin/python" --version 2>&1)
        python_ver=${python_ver/Python /}

        # Check if this venv is registered as a Jupyter kernel
        kernel_registered="No"
        for kernel_dir in "$KERNELS_DIR"/*; do
            if [[ -f "$kernel_dir/kernel.json" ]]; then
                # Extract argv[0] from kernel.json
                kernel_python=$(python3 -c "import json; print(json.load(open('$kernel_dir/kernel.json'))['argv'][0])")
                if [[ "$kernel_python" == "$venv_path/bin/python" ]]; then
                    kernel_registered="Yes"
                    break
                fi
            fi
        done

        echo "S.no. $count"
        echo "vEnv Name: $name"
        echo "Path: $venv_path"
        echo "Python Version: $python_ver"
        echo "Jupyter Kernel: $kernel_registered"
        echo "-----------------------------"
        ((count++))
    fi
done
```

---

## 4. Check all virtual environments that have registered kernel for Jupyter

```
jupyter kernelspec list
```
