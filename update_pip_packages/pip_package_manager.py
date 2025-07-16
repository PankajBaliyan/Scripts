import subprocess
import sys
import json

def list_all_packages():
    print("\n📦 Installed Packages:")
    subprocess.run([sys.executable, "-m", "pip", "list"])

def list_outdated_packages():
    print("\n🔄 Outdated Packages:")
    subprocess.run([sys.executable, "-m", "pip", "list", "--outdated", "--format=columns"])

def update_all_packages():
    print("\n⏫ Updating all outdated packages...\n")
    result = subprocess.run(
        [sys.executable, "-m", "pip", "list", "--outdated", "--format=json"],
        stdout=subprocess.PIPE,
        text=True
    )
    packages = json.loads(result.stdout)
    for pkg in packages:
        name = pkg["name"]
        print(f"⬆️  Upgrading {name}...")
        subprocess.run([sys.executable, "-m", "pip", "install", "--upgrade", name])
    print("\n✅ All packages updated.\n")

def update_requirements_file():
    print("\n📄 Updating requirements.txt with current package versions...")
    with open("requirements.txt", "w") as req_file:
        subprocess.run([sys.executable, "-m", "pip", "freeze"], stdout=req_file)
    print("✅ requirements.txt updated.\n")

def menu():
    while True:
        print("\n=== Python Package Manager ===")
        print("1 → List all packages")
        print("2 → List outdated packages")
        print("3 → Update all packages")
        print("4 → Update requirements.txt")
        print("0 → Exit")

        choice = input("Enter your choice: ").strip()

        if choice == "1":
            list_all_packages()
        elif choice == "2":
            list_outdated_packages()
        elif choice == "3":
            update_all_packages()
        elif choice == "4":
            update_requirements_file()
        elif choice == "0":
            print("👋 Exiting.")
            break
        else:
            print("❌ Invalid choice. Please enter 0-4.")

if __name__ == "__main__":
    menu()