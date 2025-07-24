// Save .my.cnf-export and run this command to set permissions
// Description: This script exports MySQL credentials to a .my.cnf file for secure access.
chmod 600 ~/.my.cnf-export
chmod 600 ./.my.cnf-export

// Run the script - to export database
chmod 700 mysql_db_export.sh && ./mysql_db_export.sh

// Run the script - to import database
brew install parallel   # macOS
sudo apt install parallel  # Ubuntu/Debian

chmod 700 mysql_db_import.sh && ./mysql_db_import.sh

// Run the script - to export tables
chmod 700 mysql_table_export.sh && ./mysql_table_export.sh

// Run the script - to import tables
chmod 700 mysql_table_import.sh && ./mysql_table_import.sh