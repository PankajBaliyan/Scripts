#!/bin/bash

CRED_FILE="./db_credentials.cnf"

# --- Helper function: safe dump execution ---
safe_mysqldump() {
    local db=$1
    local table=$2
    local outfile=$3

    # If file already exists → delete it
    if [ -f "$outfile" ]; then
        echo "ℹ️  Removing old dump file: $outfile"
        rm -f "$outfile"
    fi

    if [ -z "$table" ]; then
        # Fetch only table names (first column)
        tables=$(mysql --defaults-extra-file=$CRED_FILE -Nse \
            "SHOW FULL TABLES IN $db WHERE Table_type = 'BASE TABLE';" | awk '{print $1}')

        if [ -z "$tables" ]; then
            echo "❌ No base tables found in $db"
            return 1
        fi

        # Dump only base tables (skip views)
        mysqldump --defaults-extra-file=$CRED_FILE \
                  --skip-lock-tables --single-transaction --no-tablespaces \
                  "$db" $tables > "$outfile" 2> dump_error.log
    else
        # Dump a single table
        mysqldump --defaults-extra-file=$CRED_FILE \
                  --skip-lock-tables --single-transaction --no-tablespaces \
                  "$db" "$table" > "$outfile" 2> dump_error.log
    fi

    if [ $? -ne 0 ]; then
        echo "❌ Dump failed for $db${table:+.$table}"
        cat dump_error.log
        rm -f "$outfile"
        return 1
    fi

    echo "✅ Dump successful: $outfile"
    return 0
}


# --- Dump selected database ---
dump_database() {
    echo "Fetching databases..."
    databases=$(mysql --defaults-extra-file=$CRED_FILE -Nse "SHOW DATABASES;")

    db_list=()
    i=1
    for db in $databases; do
        echo "$i) $db"
        db_list+=("$db")
        ((i++))
    done

    read -p "Enter the number of the database you want to dump: " db_num
    idx=$((db_num-1))
    selected_db="${db_list[$idx]}"

    if [ -z "$selected_db" ]; then
        echo "❌ Invalid selection."
        return
    fi

    mkdir -p ./dump_databases
    outfile="./dump_databases/${selected_db}.sql"
    safe_mysqldump "$selected_db" "" "$outfile"
}

# --- Dump selected table ---
dump_table() {
    read -p "Enter database name: " db_name

    echo "Fetching tables from $db_name..."
    tables=$(mysql --defaults-extra-file=$CRED_FILE -Nse "SHOW FULL TABLES FROM $db_name WHERE Table_type = 'BASE TABLE'")

    i=1
    declare -A table_map
    for tbl in $tables; do
        echo "$i) $tbl"
        table_map[$i]=$tbl
        ((i++))
    done

    read -p "Enter the number of the table you want to dump: " tbl_num
    selected_table=${table_map[$tbl_num]}

    if [ -z "$selected_table" ]; then
        echo "❌ Invalid selection."
        return
    fi

    mkdir -p ./dump_tables
    outfile="./dump_tables/${db_name}_${selected_table}.sql"
    safe_mysqldump "$db_name" "$selected_table" "$outfile"
}

# --- Relocate space (cleanup) ---
relocate_space() {
    echo "Fetching databases..."
    databases=$(mysql --defaults-extra-file=$CRED_FILE -Nse "SHOW DATABASES;")

    i=1
    declare -A db_map
    for db in $databases; do
        echo "$i) $db"
        db_map[$i]=$db
        ((i++))
    done

    read -p "Enter the number of the database you want to clean: " db_num
    selected_db=${db_map[$db_num]}

    if [ -z "$selected_db" ]; then
        echo "❌ Invalid selection."
        return
    fi

    echo "⚡ Starting cleanup for DB: $selected_db"
    BACKUP_DIR="./backups"
    mkdir -p $BACKUP_DIR

    tables=$(mysql --defaults-extra-file=$CRED_FILE -Nse "SHOW FULL TABLES FROM $selected_db WHERE Table_type = 'BASE TABLE'")

    for table in $tables; do
        echo "Processing table: $table"

        outfile="$BACKUP_DIR/${table}.sql"
        safe_mysqldump "$selected_db" "$table" "$outfile" || continue

        # Drop with foreign key check disabled
        echo "SET FOREIGN_KEY_CHECKS=0; DROP TABLE IF EXISTS \`$table\`; SET FOREIGN_KEY_CHECKS=1;" \
            | mysql --defaults-extra-file=$CRED_FILE $selected_db 2> drop_error.log

        if grep -q "ERROR 3730" drop_error.log; then
            echo "⚠️ Skipping drop for $table due to foreign key constraint"
            continue
        fi

        # Restore the table
        mysql --defaults-extra-file=$CRED_FILE $selected_db < "$outfile"
        echo "✅ Table $table cleaned and restored"
    done

    rm -rf $BACKUP_DIR
    echo "🧹 Backup folder deleted after successful run."
    echo "✅ All tables cleaned and restored."
}

# --- Show database sizes ---
show_database_sizes() {
    echo "📊 Fetching database sizes..."
    mysql --defaults-extra-file=$CRED_FILE -t <<EOF
    SELECT 
        table_schema as 'Database',
        CASE
            WHEN SUM(data_length + index_length) > 1024*1024*1024*1024 
                THEN CONCAT(ROUND(SUM(data_length + index_length)/(1024*1024*1024*1024),2),' TB')
            WHEN SUM(data_length + index_length) > 1024*1024*1024 
                THEN CONCAT(ROUND(SUM(data_length + index_length)/(1024*1024*1024),2),' GB')
            WHEN SUM(data_length + index_length) > 1024*1024 
                THEN CONCAT(ROUND(SUM(data_length + index_length)/(1024*1024),2),' MB')
            ELSE CONCAT(ROUND(SUM(data_length + index_length)/1024,2),' KB')
        END as 'Size',
        COUNT(*) as 'Tables'
    FROM information_schema.tables
    WHERE table_type='BASE TABLE'
    GROUP BY table_schema
    ORDER BY SUM(data_length + index_length) DESC;
EOF
}

# --- Show table sizes for a database ---
show_table_sizes() {
  if [[ -z "$CRED_FILE" || ! -f "$CRED_FILE" ]]; then
    echo "❌ CRED_FILE is not set or file not found."
    return 1
  fi

  echo "Fetching databases..."
  mapfile -t databases < <(mysql --defaults-extra-file="$CRED_FILE" -Nse "SHOW DATABASES;" 2>/dev/null)
  if [[ ${#databases[@]} -eq 0 ]]; then
    echo "❌ No databases found or cannot connect."
    return 1
  fi

  echo "Select a database:"
  select selected_db in "${databases[@]}"; do
    if [[ -n "$selected_db" ]]; then
      break
    else
      echo "❌ Invalid selection. Try again."
    fi
  done

  echo "📊 Fetching table sizes for database: $selected_db"
  mysql --defaults-extra-file="$CRED_FILE" -t -e "
    SELECT 
      TABLE_NAME AS 'Table',
      CASE
        WHEN (data_length + index_length) >= 1024*1024*1024*1024 
          THEN CONCAT(ROUND((data_length + index_length)/(1024*1024*1024*1024),2),' TB')
        WHEN (data_length + index_length) >= 1024*1024*1024 
          THEN CONCAT(ROUND((data_length + index_length)/(1024*1024*1024),2),' GB')
        WHEN (data_length + index_length) >= 1024*1024 
          THEN CONCAT(ROUND((data_length + index_length)/(1024*1024),2),' MB')
        ELSE CONCAT(ROUND((data_length + index_length)/1024,2),' KB')
      END AS 'Size',
      TABLE_ROWS AS 'Rows',
      CREATE_TIME AS 'Created',
      UPDATE_TIME AS 'Updated'
    FROM information_schema.tables 
    WHERE table_schema = '${selected_db}'
      AND table_type = 'BASE TABLE'
    ORDER BY (data_length + index_length) DESC;
  "
}

# --- Compressed full database backup ---
compressed_backup() {
    echo "Fetching databases..."
    databases=$(mysql --defaults-extra-file=$CRED_FILE -Nse "SHOW DATABASES;" | grep -Ev "^(information_schema|performance_schema|sys|mysql)$")

    i=1
    declare -A db_map
    for db in $databases; do
        echo "$i) $db"
        db_map[$i]=$db
        ((i++))
    done

    read -p "Enter the number of the database to backup: " db_num
    selected_db=${db_map[$db_num]}

    if [ -z "$selected_db" ]; then
        echo "❌ Invalid selection."
        return
    fi

    # Create backup directory if it doesn't exist
    backup_dir="./compressed_backups"
    mkdir -p "$backup_dir"

    # Generate timestamp for backup file
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_file="${backup_dir}/${selected_db}_${timestamp}.sql.gz"

    echo "📦 Creating compressed backup of $selected_db..."
    mysqldump --defaults-extra-file=$CRED_FILE \
              --single-transaction \
              --routines \
              --triggers \
              --events \
              --skip-lock-tables \
              --databases "$selected_db" 2> backup_error.log | gzip > "$backup_file"

    if [ $? -eq 0 ]; then
        # Get the size of the backup file
        size=$(ls -lh "$backup_file" | awk '{print $5}')
        echo "✅ Backup successful!"
        echo "📂 Location: $backup_file"
        echo "📊 Compressed size: $size"
    else
        echo "❌ Backup failed!"
        cat backup_error.log
        rm -f "$backup_file"
    fi
}

# --- Delete database and all its content ---
delete_database() {
    echo -e "\nFetching databases...\n"
    databases=$(mysql --defaults-extra-file=$CRED_FILE -Nse "SHOW DATABASES;" | grep -Ev "^(information_schema|performance_schema|sys|mysql)$")

    db_list=()
    i=1
    printf "   e) Back to main menu\n"
    for db in $databases; do
        printf "  %2d) %s\n" "$i" "$db"
        db_list+=("$db")
        ((i++))
    done

    echo
    read -p "Enter the number(s) of the database(s) to DELETE (comma-separated, or 'e' to exit): " db_nums

    # Handle exit
    if [[ "$db_nums" == "e" || "$db_nums" == "E" ]]; then
        echo "↩️  Returning to main menu..."
        return
    fi

    # Remove spaces and split by comma
    db_nums_clean=$(echo "$db_nums" | tr -d ' ')
    IFS=',' read -ra indices <<< "$db_nums_clean"

    selected_dbs=()
    for db_num in "${indices[@]}"; do
        idx=$((db_num-1))
        selected_db="${db_list[$idx]}"
        if [ -z "$selected_db" ]; then
            echo -e "\n❌ Invalid selection: $db_num\n"
            continue
        fi
        selected_dbs+=("$selected_db")
    done

    if [ ${#selected_dbs[@]} -eq 0 ]; then
        echo -e "\n❌ No valid databases selected.\n"
        return
    fi

    echo -e "\n⚠️  You are about to permanently DELETE the following databases:"
    for db in "${selected_dbs[@]}"; do
        echo "   - $db"
    done
    read -p "Type YES to confirm: " confirm
    if [[ "$(echo "$confirm" | tr '[:upper:]' '[:lower:]')" != "yes" ]]; then
        echo -e "\n❌ Aborted. No databases deleted.\n"
        return
    fi

    for db in "${selected_dbs[@]}"; do
        echo -e "\n🗑️  Dropping database '$db'...\n"
        mysql --defaults-extra-file=$CRED_FILE -e "DROP DATABASE \`$db\`;" 2> drop_db_error.log

        if [ $? -eq 0 ]; then
            echo -e "✅ Database '$db' deleted successfully.\n"
        else
            echo -e "❌ Failed to delete database '$db'.\n"
            cat drop_db_error.log
        fi
    done
}

# --- Menu loop ---
while true; do
    echo -e "\n=== MySQL Cleanup Tool ==="
    echo "1 -> Dump database"
    echo "2 -> Dump table"
    echo "3 -> Relocate space (cleanup & restore tables)"
    echo "4 -> 📊 Show database sizes"
    echo "5 -> Show table sizes in database"
    echo "6 -> Full database backup (compressed)"
    echo "7 -> 🗑️  Delete database's and all its content"
    echo "e -> Exit"
    read -p "Choose an option: " choice

    case $choice in
        1) dump_database ;;
        2) dump_table ;;
        3) relocate_space ;;
        4) show_database_sizes ;;
        5) show_table_sizes ;;
        6) compressed_backup ;;
        7) delete_database ;;
        e|E) echo "👋 Exiting."; exit 0 ;;
        *) echo "❌ Invalid option." ;;
    esac
done
