import os
import argparse
from io import StringIO

def print_tree(root, max_depth, current_depth=0, prefix="", output=None):
    if current_depth > max_depth:
        return

    entries = [e for e in os.listdir(root) if os.path.isdir(os.path.join(root, e))]
    entries.sort()

    for index, entry in enumerate(entries):
        connector = "└── " if index == len(entries) - 1 else "├── "
        output.write(prefix + connector + entry + "\n")

        new_prefix = prefix + ("    " if index == len(entries) - 1 else "│   ")
        print_tree(os.path.join(root, entry), max_depth, current_depth + 1, new_prefix, output=output)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Print folder structure like a tree.")
    parser.add_argument(
        "--depth", "-d", type=int, required=True,
        help="Max depth level to print (e.g., 1, 2, 3)"
    )
    args = parser.parse_args()

    root_dir = os.getcwd()
    output = StringIO()
    output.write(os.path.basename(root_dir) + "\n")
    print_tree(root_dir, args.depth, output=output)

    with open("folder_structure.txt", "w") as f:
        f.write(output.getvalue())
    print("Folder structure written to folder_structure.txt")