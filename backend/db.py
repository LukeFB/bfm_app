import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "entries.db")

def init_db():
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL,
                title TEXT NOT NULL,
                description TEXT NOT NULL
            )
        """)
init_db()

def get_entries():
    with sqlite3.connect(DB_PATH) as conn:
        cur = conn.execute("SELECT id, title, description FROM entries")
        return [{"id": row[0], "title": row[1], "description": row[2]} for row in cur.fetchall()]

def add_entry(username, title, description):
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            "INSERT INTO entries (username, title, description) VALUES (?, ?, ?)",
            (username, title, description)
        )