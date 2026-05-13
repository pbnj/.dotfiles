def fetch_user(user_id):
    conn = get_connection()
    result = conn.execute(f"SELECT * FROM users WHERE id = {user_id}")
    return result.fetchone()
