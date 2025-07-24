#!/bin/bash

# === Constants ===
CREDENTIALS_FILE="./.my.cnf-export"
SERVER_OPTIONS=("local" "dev" "staging" "production")
EXPORT_DIR="./exported_databases"

# === Check credentials file ===
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "❌ Credentials file not found: $CREDENTIALS_FILE"
    exit 1
fi

# === Choose Server to Import Into ===
echo "🌐 Select server to import into:"
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
echo ""
echo "🔐 Using credentials section: $SECTION"

# === Ask for _qa suffix if local ===
ADD_QA_SUFFIX=false
if [ "$SERVER" == "local" ]; then
    read -p "❓ Do you want to add '_qa' suffix to database names? (y/n): " suffix_choice
    [[ "$suffix_choice" == "y" || "$suffix_choice" == "Y" ]] && ADD_QA_SUFFIX=true
fi

# === Create temporary .cnf file ===
TMP_CNF=$(mktemp)
{
    echo "[client]"
    awk "/^\[client_${SERVER}\]/ {flag=1; next} /^\[client_/ {flag=0} flag" "$CREDENTIALS_FILE"
} >"$TMP_CNF"
chmod 600 "$TMP_CNF"

# === List available .sql files ===
if [ ! -d "$EXPORT_DIR" ]; then
    echo "❌ Exported database directory not found: $EXPORT_DIR"
    rm -f "$TMP_CNF"
    exit 1
fi

SQL_FILES=($(find "$EXPORT_DIR" -maxdepth 1 -type f -name "*.sql"))
if [ ${#SQL_FILES[@]} -eq 0 ]; then
    echo "❌ No exported .sql files found in $EXPORT_DIR"
    rm -f "$TMP_CNF"
    exit 1
fi

echo ""
echo "📦 Available exported databases:"
i=1
DB_NAMES=()
for file in "${SQL_FILES[@]}"; do
    fname=$(basename "$file")
    db="${fname%.sql}"
    DB_NAMES+=("$db")
    echo "$i) $db"
    ((i++))
done

read -p "Enter number(s) to import (e.g., 1,2 or '0' for all, or 'e' to exit): " choice

if [[ "$choice" == "e" ]]; then
    echo "👋 Exiting..."
    rm -f "$TMP_CNF"
    exit 0
fi

SELECTED_DBS=()

if [[ "$choice" == "0" ]]; then
    SELECTED_DBS=("${DB_NAMES[@]}")
else
    IFS=',' read -ra INDEXES <<< "$choice"
    for idx in "${INDEXES[@]}"; do
        if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -lt 1 ] || [ "$idx" -gt "${#DB_NAMES[@]}" ]; then
            echo "⚠️ Invalid selection: $idx"
        else
            SELECTED_DBS+=("${DB_NAMES[$((idx - 1))]}")
        fi
    done
fi

# === Function to import one database ===
import_db() {
    local DB_BASE_NAME="$1"
    local TMP_CNF="$2"
    local ADD_QA_SUFFIX="$3"

    local SQL_FILE="${EXPORT_DIR}/${DB_BASE_NAME}.sql"
    if [ ! -f "$SQL_FILE" ]; then
        echo "❌ SQL file not found: $SQL_FILE"
        return
    fi

    local DB_NAME="$DB_BASE_NAME"
    if [ "$ADD_QA_SUFFIX" = true ]; then
        DB_NAME="${DB_NAME}_qa"
    fi

    echo "📥 Preparing to import '$DB_BASE_NAME'..."

    DB_EXISTS=$(mysql --defaults-extra-file="$TMP_CNF" -e "SHOW DATABASES LIKE '${DB_NAME}';" | grep -w "$DB_NAME")
    if [ -z "$DB_EXISTS" ]; then
        echo ""
        echo "🛠️ Creating database '$DB_NAME'..."
        mysql --defaults-extra-file="$TMP_CNF" -e "CREATE DATABASE \`${DB_NAME}\`;"
    else
        echo ""
        echo "♻️ Dropping all tables in existing DB '$DB_NAME'..."
        TABLES=$(mysql --defaults-extra-file="$TMP_CNF" "$DB_NAME" -Nse 'SHOW TABLES;')
        for tbl in $TABLES; do
            mysql --defaults-extra-file="$TMP_CNF" "$DB_NAME" -e "DROP TABLE IF EXISTS \`${tbl}\`;"
        done
    fi

    echo "📤 Importing '$DB_NAME' from '$SQL_FILE'..."
    mysql --defaults-extra-file="$TMP_CNF" "$DB_NAME" <"$SQL_FILE"

    if [ $? -eq 0 ]; then
        echo "✅ Successfully imported '$DB_NAME'"
    else
        echo "❌ Failed to import '$DB_NAME'"
    fi
}

# === Import in Parallel if more than one DB ===
if [ "${#SELECTED_DBS[@]}" -gt 1 ] && command -v parallel >/dev/null 2>&1; then
    echo "🚀 Importing in parallel using GNU Parallel..."
    export -f import_db
    export EXPORT_DIR TMP_CNF ADD_QA_SUFFIX
    parallel import_db {} "$TMP_CNF" "$ADD_QA_SUFFIX" ::: "${SELECTED_DBS[@]}"
else
    echo ""
    echo "➡️ Importing sequentially..."
    for DB in "${SELECTED_DBS[@]}"; do
        import_db "$DB" "$TMP_CNF" "$ADD_QA_SUFFIX"
    done
fi

# === Cleanup ===
rm -f "$TMP_CNF"
