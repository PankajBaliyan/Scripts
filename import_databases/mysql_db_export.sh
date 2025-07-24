#!/bin/bash

# === Constants ===
# CREDENTIALS_FILE="$HOME/.my.cnf-export"
CREDENTIALS_FILE="./.my.cnf-export"
SERVER_OPTIONS=("local" "dev" "staging" "production")
EXPORT_DIR="./exported_databases"

# === Check credentials file ===
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "❌ Credentials file not found: $CREDENTIALS_FILE"
    exit 1
fi

# === Choose Server ===
echo "🌐 Select server to connect:"
i=1
for srv in "${SERVER_OPTIONS[@]}"; do
    echo "$i) $srv"
    ((i++))
done

read -p "Enter number [1-${#SERVER_OPTIONS[@]}]: " srv_choice
if ! [[ "$srv_choice" =~ ^[1-4]$ ]]; then
    echo "❌ Invalid server choice."
    exit 1
fi

SERVER="${SERVER_OPTIONS[$((srv_choice - 1))]}"
SECTION="[client_${SERVER}]"
echo "🔑 Using credentials section: $SECTION"

# === Create temporary .cnf file with forced [client] section ===
TMP_CNF=$(mktemp)
{
    echo "[client]"
    awk "/^\[client_${SERVER}\]/ {flag=1; next} /^\[client_/ {flag=0} flag" "$CREDENTIALS_FILE"
} >"$TMP_CNF"
chmod 600 "$TMP_CNF"

# === Create export directory if it doesn't exist ===
mkdir -p "$EXPORT_DIR"

# === Fetch databases (excluding internal ones) ===
DATABASES=$(mysql --defaults-extra-file="$TMP_CNF" -e "SHOW DATABASES;" 2>error.log | grep -vE "^(Database|information_schema|performance_schema|mysql|sys)$")
if [ $? -ne 0 ] || [ -z "$DATABASES" ]; then
    echo "❌ Login failed or no databases found. Error:"
    cat error.log
    rm -f "$TMP_CNF"
    exit 1
fi

# === Display menu ===
DATABASE_ARRAY=()
i=1
echo "📚 Available Databases on $SERVER:"
echo "0) ALL databases"
for db in $DATABASES; do
    DATABASE_ARRAY+=("$db")
    echo "$i) $db"
    ((i++))
done

# === Prompt for export ===
EXPORTED_DBS=()
while true; do
    echo
    read -p "Enter number(s) to export (e.g., 2,3 or 0 for all, or 'e' to exit): " choice

    if [[ "$choice" == "e" ]]; then
        echo "👋 Exiting..."
        break

    elif [[ "$choice" == "0" ]]; then
        echo "📤 Exporting EACH database to separate .sql files..."
        for DB_NAME in "${DATABASE_ARRAY[@]}"; do
            FILE_NAME="${EXPORT_DIR}/${DB_NAME}.sql"
            echo "📤 Exporting '$DB_NAME' to '$FILE_NAME'..."
            mysqldump --defaults-extra-file="$TMP_CNF" --single-transaction --set-gtid-purged=OFF "$DB_NAME" >"$FILE_NAME"
            if [ $? -eq 0 ]; then
                EXPORTED_DBS+=("$DB_NAME")
                echo "✅ Exported '$DB_NAME'"
            else
                echo "❌ Failed to export '$DB_NAME'"
            fi
        done
        break

    elif [[ "$choice" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
        IFS=',' read -ra SELECTED <<<"$choice"
        for index in "${SELECTED[@]}"; do
            if ! [[ "$index" =~ ^[0-9]+$ ]] || [ "$index" -lt 1 ] || [ "$index" -gt "${#DATABASE_ARRAY[@]}" ]; then
                echo "⚠️ Invalid selection: $index"
                continue
            fi
            DB_NAME=${DATABASE_ARRAY[$((index - 1))]}
            FILE_NAME="${EXPORT_DIR}/${DB_NAME}.sql"
            echo "📤 Exporting '$DB_NAME' to '$FILE_NAME'..."
            mysqldump --defaults-extra-file="$TMP_CNF" --single-transaction --set-gtid-purged=OFF "$DB_NAME" >"$FILE_NAME"
            if [ $? -eq 0 ]; then
                EXPORTED_DBS+=("$DB_NAME")
                echo "✅ Exported '$DB_NAME'"
            else
                echo "❌ Failed to export '$DB_NAME'" 
            fi
        done
        break

    else
        echo "⚠️ Invalid input. Use numbers like 2,3 or 0, or 'e' to exit."
    fi
done

# === Cleanup ===
rm -f "$TMP_CNF"

# === Ask for import ===
if [ ${#EXPORTED_DBS[@]} -eq 0 ]; then
    echo "ℹ️ No databases were exported. Skipping import."
    exit 0
fi

read -p "📥 Do you want to import the exported DB(s) to local server? [y/n]: " import_choice
if [[ "$import_choice" != "y" ]]; then
    echo "👋 Skipping import."
    exit 0
fi

# === Prepare credentials for local import ===
TMP_LOCAL_CNF=$(mktemp)
{
    echo "[client]"
    awk "/^\[client_local\]/ {flag=1; next} /^\[client_/ {flag=0} flag" "$CREDENTIALS_FILE"
} >"$TMP_LOCAL_CNF"
chmod 600 "$TMP_LOCAL_CNF"

# === Import loop ===
for DB_NAME in "${EXPORTED_DBS[@]}"; do
    SQL_FILE="${EXPORT_DIR}/${DB_NAME}.sql"
    echo "📥 Importing '$DB_NAME' from '$SQL_FILE'..."
    mysql --defaults-extra-file="$TMP_LOCAL_CNF" -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`; CREATE DATABASE \`${DB_NAME}\`;"
    mysql --defaults-extra-file="$TMP_LOCAL_CNF" "$DB_NAME" <"$SQL_FILE"
    if [ $? -eq 0 ]; then
        echo "✅ Imported '$DB_NAME' into local server"
    else
        echo "❌ Failed to import '$DB_NAME'"
    fi
done

# === Cleanup local temp config ===
rm -f "$TMP_LOCAL_CNF"
