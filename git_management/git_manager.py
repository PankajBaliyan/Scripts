import subprocess
import sys
import re
import os

# --- ANSI Color Codes ---
class Colors:
    """A class to hold ANSI color codes for terminal output."""
    RESET = '\033[0m'
    BOLD = '\033[1m'
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'

# --- Helper Functions ---
def print_error(message):
    print(f"{Colors.RED}❌  {message}{Colors.RESET}")

def print_success(message):
    print(f"{Colors.GREEN}✅  {message}{Colors.RESET}")

def print_info(message):
    print(f"{Colors.BLUE}ℹ️  {message}{Colors.RESET}")

def print_warning(message):
    print(f"{Colors.YELLOW}⚠️  {message}{Colors.RESET}")

def run_command(command, suppress_error=False):
    """Executes a shell command and returns its output."""
    try:
        result = subprocess.run(
            command,
            check=True,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        if not suppress_error:
            print_error(f"Error executing command: '{command}'")
            print_error(f"Error: {e.stderr.strip()}")
        return None
    except FileNotFoundError:
        print_error("'git' command not found. Is Git installed and in your PATH?")
        sys.exit(1)

def is_git_repository():
    """Check if the current directory is a Git repository."""
    return run_command("git rev-parse --is-inside-work-tree") == "true"

def select_from_list(items, prompt, title_color=Colors.CYAN):
    """Displays a numbered list and prompts the user for a selection."""
    if not items:
        print_warning("No items to select.")
        return None

    print(f"{title_color}{prompt}{Colors.RESET}")
    for i, item in enumerate(items, 1):
        print(f"  [{i}] {item}")

    while True:
        try:
            choice = input("Enter number (or 'c' to cancel): ")
            if choice.lower() == 'c':
                return None
            choice_num = int(choice)
            if 1 <= choice_num <= len(items):
                return items[choice_num - 1]
            else:
                print_warning("Invalid number. Please try again.")
        except ValueError:
            print_warning("Invalid input. Please enter a number.")

# --- Git Feature Functions ---
def list_local_branches():
    """1. Lists all local branches."""
    print_info("Listing local branches...")
    output = run_command("git branch --sort=-committerdate --color=always")
    if output:
        print(output)

def list_remote_branches():
    """2. Lists all remote branches."""
    print_info("Listing remote branches...")
    output = run_command("git branch -r --sort=-committerdate --color=always")
    if output:
        print(output)

def prune_stale_branches():
    """3. Finds and offers to delete local branches whose remote counterpart is gone."""
    print_info("Checking for stale local branches...")
    print("   Fetching from remote and pruning...")
    run_command("git fetch --prune")
    verbose_output = run_command("git branch -vv")
    if verbose_output is None: return

    stale_branches = [m.group(1) for m in re.finditer(r"^\s*(\S+)\s+[a-f0-9]+\s+\[\S+: gone\].*", verbose_output, re.MULTILINE)]

    if not stale_branches:
        print_success("No stale local branches found.")
        return

    print_warning("\nThe following local branches track remote branches that have been deleted:")
    for branch in stale_branches:
        print(f"  - {branch}")

    if input("\nDo you want to delete these local branches? (y/n): ").lower() == 'y':
        for branch in stale_branches:
            print(f"   Deleting branch '{branch}'...")
            run_command(f"git branch -d {branch}")
        print_success("Done.")
    else:
        print_info("Aborted. No branches were deleted.")

def sync_remote_branches():
    """4. Fetches and creates local copies of new remote branches."""
    print_info("Syncing remote branches to local...")
    print("   Fetching all remote information...")
    run_command("git fetch")

    remote_branches_raw = run_command("git branch -r")
    local_branches_raw = run_command("git branch")
    if remote_branches_raw is None or local_branches_raw is None: return

    local_branches = {b.replace('*', '').strip() for b in local_branches_raw.split('\n')}
    new_branches = [b.split('/', 1)[-1] for b in remote_branches_raw.split('\n') if '->' not in b and b.split('/', 1)[-1].strip() not in local_branches]

    if not new_branches:
        print_success("Your local repository is already in sync with all remote branches.")
        return

    print_info("\nThe following new remote branches are available:")
    for branch in new_branches:
        print(f"  - {branch}")
        
    if input("\nDo you want to create local tracking branches for them? (y/n): ").lower() == 'y':
        for branch in new_branches:
            print(f"   Creating and tracking 'origin/{branch}'...")
            run_command(f"git branch --track {branch} origin/{branch}")
        print_success("Done.")
    else:
        print_info("Aborted. No new branches were created.")

def switch_branch():
    """5. Switch to a different local branch."""
    local_branches_raw = run_command("git branch --format='%(refname:short)'")
    if not local_branches_raw:
        print_warning("No local branches found.")
        return
        
    branches = local_branches_raw.split('\n')
    selected_branch = select_from_list(branches, "Select a branch to switch to:")
    
    if selected_branch:
        print_info(f"Switching to branch '{selected_branch}'...")
        output = run_command(f"git checkout {selected_branch}")
        if output is not None:
            print_success(f"Switched to branch '{selected_branch}'.")
            print(output)

def delete_branch_menu():
    """6. Menu for deleting local or remote branches."""
    while True:
        print_info("Delete a Branch:")
        choice = input("Delete (1) Local or (2) Remote branch? (c to cancel): ").lower()
        if choice == '1':
            delete_local_branch()
            break
        elif choice == '2':
            delete_remote_branch()
            break
        elif choice == 'c':
            break
        else:
            print_warning("Invalid choice.")

def delete_local_branch():
    current_branch = run_command("git rev-parse --abbrev-ref HEAD")
    branches_raw = run_command("git branch --format='%(refname:short)'")
    branches = [b for b in branches_raw.split('\n') if b != current_branch]
    
    if not branches:
        print_warning("No other local branches to delete.")
        return
    
    branch_to_delete = select_from_list(branches, "Select a local branch to delete:")
    if not branch_to_delete: return

    force = input(f"Force delete '{branch_to_delete}'? (requires -D flag) (y/n): ").lower()
    flag = "-D" if force == 'y' else "-d"
    
    print_info(f"Attempting to delete '{branch_to_delete}'...")
    output = run_command(f"git branch {flag} {branch_to_delete}")
    if output is not None:
        print_success(output)

def delete_remote_branch():
    branches_raw = run_command("git branch -r --format='%(refname:short)'")
    branches = [b for b in branches_raw.split('\n') if '->' not in b]
    
    if not branches:
        print_warning("No remote branches to delete.")
        return
    
    branch_to_delete = select_from_list(branches, "Select a remote branch to delete:")
    if not branch_to_delete: return
    
    remote_name, branch_name = branch_to_delete.split('/', 1)
    
    if input(f"Are you sure you want to delete '{branch_to_delete}' from remote? (y/n): ").lower() == 'y':
        print_info(f"Deleting '{branch_name}' from remote '{remote_name}'...")
        output = run_command(f"git push {remote_name} --delete {branch_name}")
        if output is not None:
            print_success("Remote branch deleted successfully.")
            print(output)
    else:
        print_info("Delete operation aborted.")

def stash_menu():
    """7. Menu for Git stash operations."""
    menu = {
        '1': ('Create Stash', create_stash),
        '2': ('List Stashes', list_stashes),
        '3': ('Apply (Pop) Stash', apply_stash),
    }
    while True:
        print(f"\n{Colors.MAGENTA}--- 🗄️ Stash Manager ---{Colors.RESET}")
        for key, (desc, _) in menu.items():
            print(f"{key} : {desc}")
        print("B : Back to main menu")

        choice = input("Enter your choice: ").lower()
        if choice == 'b':
            break
        elif choice in menu:
            menu[choice][1]()
        else:
            print_warning("Invalid choice.")

def create_stash():
    message = input("Enter an optional message for the stash: ")
    command = "git stash push"
    if message:
        command += f" -m \"{message}\""
    
    output = run_command(command, suppress_error=True)
    if output is not None:
        if "No local changes to save" in output:
            print_warning("No local changes to stash.")
        else:
            print_success("Changes stashed successfully.")
    else:
        print_error("Failed to stash changes.")

def list_stashes():
    print_info("Listing stashes...")
    output = run_command("git stash list --color=always")
    if output:
        print(output)
    else:
        print_success("No stashes found.")

def apply_stash():
    if not run_command("git stash list"):
        print_warning("No stashes to apply.")
        return
    
    print_info("Applying the most recent stash (git stash pop)...")
    output = run_command("git stash pop")
    if output is not None:
        print_success("Stash applied successfully.")
        print(output)
        
# --- Main Application ---
def main():
    """Main function to run the Git branch manager."""
    if not is_git_repository():
        print_error("This is not a Git repository. Please run the script from a repo directory.")
        sys.exit(1)

    main_menu = {
        '1': ('🌿  List local branches', list_local_branches),
        '2': ('🌐  List remote branches', list_remote_branches),
        '3': ('🧹  Prune stale local branches', prune_stale_branches),
        '4': ('🔄  Sync new remote branches', sync_remote_branches),
        '5': ('🔀  Switch branch', switch_branch),
        '6': ('🗑️  Delete a branch...', delete_branch_menu),
        '7': ('🗄️  Stash Manager...', stash_menu),
    }

    while True:
        print(f"\n{Colors.BOLD}{Colors.CYAN}--- 🐍  Git Branch Manager ---{Colors.RESET}")
        for key, (desc, _) in main_menu.items():
            print(f"{key} : {desc}")
        print("E : Exit")
        
        choice = input("\nEnter your choice: ").lower()

        if choice == 'e':
            print_info("👋 Exiting script. Goodbye!")
            break
        elif choice in main_menu:
            print("-" * 30)
            main_menu[choice][1]() # Call the function
            print("-" * 30)
        else:
            print_warning("Invalid choice, please try again.")

if __name__ == "__main__":
    main()