import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "auth.db")

def init_auth_db():
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS users (
                username TEXT PRIMARY KEY,
                user_id BLOB NOT NULL
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS credentials (
                username TEXT PRIMARY KEY,
                credential_id BLOB NOT NULL,
                public_key BLOB NOT NULL,
                sign_count INTEGER NOT NULL
            )
        """)
init_auth_db()

def set_user(username, user_id):
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            "INSERT OR REPLACE INTO users (username, user_id) VALUES (?, ?)",
            (username, user_id)
        )

def get_user(username):
    with sqlite3.connect(DB_PATH) as conn:
        cur = conn.execute(
            "SELECT user_id FROM users WHERE username = ?",
            (username,)
        )
        row = cur.fetchone()
        if row:
            return {"id": row[0], "name": username}
        return None

def set_credential(username, credential_id, public_key, sign_count):
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            "INSERT OR REPLACE INTO credentials (username, credential_id, public_key, sign_count) VALUES (?, ?, ?, ?)",
            (username, credential_id, public_key, sign_count)
        )

def get_credential(username):
    with sqlite3.connect(DB_PATH) as conn:
        cur = conn.execute(
            "SELECT credential_id, public_key, sign_count FROM credentials WHERE username = ?",
            (username,)
        )
        row = cur.fetchone()
        if row:
            return {
                "credential_id": row[0],
                "public_key": row[1],
                "sign_count": row[2]
            }
        return None

def set_user_challenge(username, challenge):
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            "CREATE TABLE IF NOT EXISTS user_challenges (username TEXT PRIMARY KEY, challenge TEXT NOT NULL)"
        )
        conn.execute(
            "INSERT OR REPLACE INTO user_challenges (username, challenge) VALUES (?, ?)",
            (username, challenge)
        )

def get_user_challenge(username):
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            "CREATE TABLE IF NOT EXISTS user_challenges (username TEXT PRIMARY KEY, challenge TEXT NOT NULL)"
        )
        cur = conn.execute(
            "SELECT challenge FROM user_challenges WHERE username = ?",
            (username,)
        )
        row = cur.fetchone()
        return row[0] if row else None

# Replace all uses of USERS and CREDENTIALS in your endpoints with these functions.
# For example, in /register/options:
# 
# 
# In /register/verify:
# user = 
# challenge = get_user_challenge(username)
# In /auth/options:
# cred = get_credential(username)
# In /auth/verify:
# cred = get_credential(username)