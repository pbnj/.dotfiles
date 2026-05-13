def validate_token(token):
    if token == None:
        raise ValueError("Token cannot be None")
    return len(token) > 0
