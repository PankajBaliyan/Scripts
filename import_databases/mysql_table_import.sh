#!/bin/bash

# === Constants ===
CREDENTIALS_FILE="./.my.cnf-export"
SERVER_OPTIONS=("local" "dev" "staging" "production")
EXPORT_DIR="./exported_tables"
ERROR_LOG_DIR="./import_errors"

# === Check credentials file ===
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "❌ Credentials file not found: $CREDENTIALS_FILE"
    exit 1
fi

# === Choose server ===
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
    read -p "❓ Do you want to add '_qa' suffix to the database name? (y/n): " suffix_choice
    [[ "$suffix_choice" == "y" || "$suffix_choice" == "Y" ]] && ADD_QA_SUFFIX=true
fi

# === Create temporary .cnf file ===
TMP_CNF=$(mktemp)
{
    echo "[client]"
    awk "/^\[client_${SERVER}\]/ {flag=1; next} /^\[client_/ {flag=0} flag" "$CREDENTIALS_FILE"
} >"$TMP_CNF"
chmod 600 "$TMP_CNF"

# === List exported database folders ===
if [ ! -d "$EXPORT_DIR" ]; then
    echo "❌ Exported table directory not found: $EXPORT_DIR"
    rm -f "$TMP_CNF"
    exit 1
fi

DB_FOLDERS=($(find "$EXPORT_DIR" -mindepth 1 -maxdepth 1 -type d))
if [ ${#DB_FOLDERS[@]} -eq 0 ]; then
    echo "❌ No exported databases found under $EXPORT_DIR"
    rm -f "$TMP_CNF"
    exit 1
fi

echo ""
echo "📚 Available exported database folders:"
i=1
DB_NAMES=()
for db_path in "${DB_FOLDERS[@]}"; do
    db=$(basename "$db_path")
    DB_NAMES+=("$db")
    echo "$i) $db"
    ((i++))
done

echo ""
read -p "Enter number of database to import tables into: " db_choice
if ! [[ "$db_choice" =~ ^[0-9]+$ ]] || [ "$db_choice" -lt 1 ] || [ "$db_choice" -gt "${#DB_NAMES[@]}" ]; then
    echo "❌ Invalid database choice."
    rm -f "$TMP_CNF"
    exit 1
fi

DB_BASE_NAME="${DB_NAMES[$((db_choice - 1))]}"
DB_NAME="$DB_BASE_NAME"
[[ "$ADD_QA_SUFFIX" == true ]] && DB_NAME="${DB_NAME}_qa"
DB_FOLDER="$EXPORT_DIR/$DB_BASE_NAME"

echo "📂 Selected Database: $DB_NAME"

# === Create DB if not exist ===
DB_EXISTS=$(mysql --defaults-extra-file="$TMP_CNF" -e "SHOW DATABASES LIKE '${DB_NAME}';" | grep -w "$DB_NAME")
if [ -z "$DB_EXISTS" ]; then
    echo "🛠️ Creating database '$DB_NAME'..."
    mysql --defaults-extra-file="$TMP_CNF" -e "CREATE DATABASE \`${DB_NAME}\`;" 2>/dev/null
else
    echo "🔁 Database '$DB_NAME' already exists."
fi

# === Create error log directory ===
mkdir -p "$ERROR_LOG_DIR"

# === List table files ===
TABLE_FILES=($(find "$DB_FOLDER" -maxdepth 1 -type f -name "*.sql" | sort))
if [ ${#TABLE_FILES[@]} -eq 0 ]; then
    echo "❌ No table .sql files found in $DB_FOLDER"
    rm -f "$TMP_CNF"
    exit 1
fi

echo ""
echo "📄 Tables available to import (Total: ${#TABLE_FILES[@]}):"
TABLE_NAMES=()
i=1
echo "0) ALL tables"
for file in "${TABLE_FILES[@]}"; do
    tbl=$(basename "$file" .sql)
    TABLE_NAMES+=("$tbl")
    echo "$i) $tbl"
    ((i++))
done

echo ""
read -p "Enter number(s) to import (e.g., 1,2,3 or 0 for all, or 'e' to exit): " choice

if [[ "$choice" == "e" ]]; then
    echo "👋 Exiting..."
    rm -f "$TMP_CNF"
    exit 0
fi

SELECTED_TABLES=()

if [[ "$choice" == "0" ]]; then
    SELECTED_TABLES=("${TABLE_NAMES[@]}")
else
    IFS=',' read -ra INDEXES <<< "$choice"
    # Trim leading/trailing spaces from each index
    for i in "${!INDEXES[@]}"; do
        INDEXES[$i]=$(echo "${INDEXES[$i]}" | sed 's/^[ \t]*//;s/[ \t]*$//')
    done
    valid_selection=false
    for idx in "${INDEXES[@]}"; do
        if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -lt 1 ] || [ "$idx" -gt "${#TABLE_NAMES[@]}" ]; then
            echo "⚠️ Invalid selection: $idx (Valid range: 1-${#TABLE_NAMES[@]})"
        else
            SELECTED_TABLES+=("${TABLE_NAMES[$((idx - 1))]}")
            valid_selection=true
        fi
    done
    if [ "$valid_selection" == false ]; then
        echo "❌ No valid tables selected. Exiting..."
        rm -f "$TMP_CNF"
        exit 1
    fi
fi

# === Import Function with timing, progress, and conditional error logging ===
import_table() {
    local tbl="$1"
    local sql_file="${DB_FOLDER}/${tbl}.sql"
    local tmp_cnf="$2"
    local db_name="$3"
    local idx="$4"
    local total="$5"
    local error_log="${ERROR_LOG_DIR}/${db_name}_${tbl}_error.log"

    echo ""
    echo "📦 [$idx/$total] Importing table: $tbl ..."
    local start=$(date +%s)

    mysql --defaults-extra-file="$tmp_cnf" "$db_name" -e "DROP TABLE IF EXISTS \`$tbl\`;" 2>/dev/null

    # Run import without redirecting errors initially to avoid creating empty log
    if mysql --defaults-extra-file="$tmp_cnf" --force "$db_name" <"$sql_file" 2>/dev/null; then
        local end=$(date +%s)
        local elapsed=$((end - start))
        echo "✅ [$idx/$total] Successfully imported table: $tbl ⏱️ (${elapsed}s)"
        echo "success" >>"$RESULTS_FILE"
    else
        # Rerun with error redirection to capture details
        mysql --defaults-extra-file="$tmp_cnf" --force "$db_name" <"$sql_file" 2>>"$error_log"
        local end=$(date +%s)
        local elapsed=$((end - start))
        echo "❌ [$idx/$total] Failed to import table: $tbl ⏱️ (${elapsed}s)"
        echo "fail:$tbl:$idx" >>"$RESULTS_FILE"
        if [ -s "$error_log" ]; then
            echo "   Error details:"
            cat "$error_log" | sed 's/^/     /'
            # Warn about hardcoded database references
            if grep -q "Unknown database" "$error_log"; then
                echo "   ⚠️ Warning: SQL file may contain hardcoded references to another database."
                echo "   Ensure the SQL file targets '$db_name' or remove 'USE' statements."
            fi
        fi
    fi
    echo "----------------------------------"
}

# === Start Importing Tables ===
echo ""
echo "🚀 Starting table imports into database: '$DB_NAME'"
echo "----------------------------------"

RESULTS_FILE=$(mktemp)
success=0
failure=0
total=${#SELECTED_TABLES[@]}
FAILED_TABLES=()

for i in "${!SELECTED_TABLES[@]}"; do
    tbl="${SELECTED_TABLES[$i]}"
    idx=$((i + 1))
    import_table "$tbl" "$TMP_CNF" "$DB_NAME" "$idx" "$total"
done | tee -a "$RESULTS_FILE"

# === Summary ===
echo ""
echo "📊 Summary ---"
while read -r line; do
    if [[ "$line" =~ ^success ]]; then
        ((success++))
    elif [[ "$line" =~ ^fail:([^:]+):([0-9]+) ]]; then
        ((failure++))
        FAILED_TABLES+=("${BASH_REMATCH[2]}: ${BASH_REMATCH[1]}")
    fi
done < "$RESULTS_FILE"

echo "✅ Success: $success"
echo "❌ Failed: $failure"

if [ $failure -gt 0 ]; then
    echo ""
    echo "📋 Failed Tables:"
    for failed in "${FAILED_TABLES[@]}"; do
        echo "  - $failed"
    done
    echo ""
    echo "ℹ️ Error details for failed tables can be found in: $ERROR_LOG_DIR"
fi

# === Cleanup ===
rm -f "$TMP_CNF" "$RESULTS_FILE"