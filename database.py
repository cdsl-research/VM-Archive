import mysql.connector
import sys

def mysql_insert_data(conn, date_time, VM_name, ESXi, hash_value, user, VM_size):
    curs = conn.cursor()
    insert_query = """
    INSERT INTO `VM_ARCHIVE_CHECK` (date_time, VM_name, ESXi, hash_value, user, VM_size)
    VALUES (%s, %s, %s, %s, %s, %s)
    """
    data = (date_time, VM_name, ESXi, hash_value, user, VM_size)
    curs.execute(insert_query, data)
    conn.commit()

def main():
    # データベースに接続
    conn = mysql.connector.connect(
        host="192.168.100.35",
        user="root",
        password="password",
        port="32000",
        database="VM_archive_DB"
    )

    if conn.is_connected():
        print("データベースに接続しました。")

    if len(sys.argv) != 7:
        print("Usage: python database.py <date_time> <VM_name> <ESXi> <hash_value> <user> <VM_size>")
        return

    date_time, VM_name, ESXi, hash_value, user, VM_size = sys.argv[1:]

    try:
        mysql_insert_data(conn, date_time, VM_name, ESXi, hash_value, user, VM_size)
        print(f"データが `VM_ARCHIVE_CHECK` テーブルに挿入されました。")
    except mysql.connector.Error as err:
        print(f"Error: {err}")
    finally:
        conn.close()
        print("データベースから切断しました。")

if __name__ == "__main__":
    main()
