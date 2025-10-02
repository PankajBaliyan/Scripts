1. Update credentials in db_credentials.cnf with your MySQL username and password.
chmod 600 db_credentials.cnf

2. Run the script from the terminal:
cd mysql_cleanup_tool
clear && chmod +x cleanup_mysql_tables.sh && ./cleanup_mysql_tables.sh





mysql_cleanup_tool/
├── cleanup_mysql_tables.sh.sh         # Main script
└── db_credentials.cnf        # MySQL credentials
