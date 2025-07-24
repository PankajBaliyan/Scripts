#!/bin/bash

# === Constants ===
CREDENTIALS_FILE="./.my.cnf-export"
SERVER_OPTIONS=("local" "dev" "staging" "production")
EXPORT_DIR="./exported_tables"

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

# === Create temporary .cnf file ===
TMP_CNF=$(mktemp)
{
    echo "[client]"
    awk "/^\[client_${SERVER}\]/ {flag=1; next} /^\[client_/ {flag=0} flag" "$CREDENTIALS_FILE"
} >"$TMP_CNF"
chmod 600 "$TMP_CNF"

# === Fetch databases ===
DATABASES=$(mysql --defaults-extra-file="$TMP_CNF" -e "SHOW DATABASES;" 2>/dev/null | grep -vE "^(Database|information_schema|performance_schema|mysql|sys)$")
if [ $? -ne 0 ] || [ -z "$DATABASES" ]; then
    echo "❌ Could not fetch databases."
    rm -f "$TMP_CNF"
    exit 1
fi

# === Choose Database ===
DATABASE_ARRAY=()
i=1
echo "📚 Available Databases on $SERVER:"
for db in $DATABASES; do
    DATABASE_ARRAY+=("$db")
    echo "$i) $db"
    ((i++))
done

read -p "Enter number of database to use: " db_choice
if ! [[ "$db_choice" =~ ^[0-9]+$ ]] || [ "$db_choice" -lt 1 ] || [ "$db_choice" -gt "${#DATABASE_ARRAY[@]}" ]; then
    echo "❌ Invalid database choice."
    rm -f "$TMP_CNF"
    exit 1
fi

DB_NAME="${DATABASE_ARRAY[$((db_choice - 1))]}"
echo "📂 Selected Database: $DB_NAME"

# === Fetch tables ===
TABLES=$(mysql --defaults-extra-file="$TMP_CNF" -D "$DB_NAME" -e "SHOW TABLES;" 2>/dev/null | tail -n +2)
if [ $? -ne 0 ] || [ -z "$TABLES" ]; then
    echo "❌ No tables found or failed to connect."
    rm -f "$TMP_CNF"
    exit 1
fi

# === Display tables with numbers ===
TABLE_ARRAY=()
i=1
echo "📄 Tables in '$DB_NAME':"
echo "0) ALL tables"
for tbl in $TABLES; do
    TABLE_ARRAY+=("$tbl")
    echo "$i) $tbl"
    ((i++))
done

# === Choose tables ===
read -p "Enter number(s) to export (e.g., 2,3 or 0 for all, or 'e' to exit): " choice
if [[ "$choice" == "e" ]]; then
    echo "👋 Exiting..."
    rm -f "$TMP_CNF"
    exit 0
fi

EXPORT_PATH="${EXPORT_DIR}/${DB_NAME}"
mkdir -p "$EXPORT_PATH"

EXPORTED_TABLES=()

if [[ "$choice" == "0" ]]; then
    echo "📤 Exporting ALL tables from $DB_NAME..."
    for tbl in "${TABLE_ARRAY[@]}"; do
        FILE="$EXPORT_PATH/${tbl}.sql"
        echo "📤 Exporting table '$tbl'..."
        mysqldump --defaults-extra-file="$TMP_CNF" --single-transaction --set-gtid-purged=OFF "$DB_NAME" "$tbl" >"$FILE"
        if [ $? -eq 0 ]; then
            echo "✅ Exported '$tbl'"
            EXPORTED_TABLES+=("$tbl")
        else
            echo "❌ Failed to export '$tbl'"
        fi
    done
else
    IFS=',' read -ra SELECTED <<<"$choice"
    for index in "${SELECTED[@]}"; do
        if ! [[ "$index" =~ ^[0-9]+$ ]] || [ "$index" -lt 1 ] || [ "$index" -gt "${#TABLE_ARRAY[@]}" ]; then
            echo "⚠️ Invalid selection: $index"
            continue
        fi
        tbl=${TABLE_ARRAY[$((index - 1))]}
        FILE="$EXPORT_PATH/${tbl}.sql"
        echo "📤 Exporting table '$tbl'..."
        mysqldump --defaults-extra-file="$TMP_CNF" --single-transaction --set-gtid-purged=OFF "$DB_NAME" "$tbl" >"$FILE"
        if [ $? -eq 0 ]; then
            echo "✅ Exported '$tbl'"
            EXPORTED_TABLES+=("$tbl")
        else
            echo "❌ Failed to export '$tbl'"
        fi
    done
fi

# === Cleanup ===
rm -f "$TMP_CNF"

# === Summary ===
if [ ${#EXPORTED_TABLES[@]} -gt 0 ]; then
    echo "✅ Export completed. Tables saved in: $EXPORT_PATH"
else
    echo "ℹ️ No tables were exported."
fi
