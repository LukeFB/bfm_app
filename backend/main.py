from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from webauthn.helpers import options_to_json_dict
from webauthn.helpers.structs import (
    AuthenticatorSelectionCriteria,
    AttestationConveyancePreference,
    UserVerificationRequirement,
    PublicKeyCredentialDescriptor,
    PublicKeyCredentialType
)
from webauthn import (
    generate_registration_options,
    verify_registration_response,
    generate_authentication_options,
    verify_authentication_response,
)
import secrets
from jose import jwt
import datetime
import os

app = FastAPI()

# Allow CORS for frontend testing
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory "database"
USERS = {}
CREDENTIALS = {}

SECRET_KEY = "super-secret-key"  # Use a secure random key in production
ALGORITHM = "HS256"

RP_ID = "localhost"
ORIGIN = "http://localhost:3000"

def create_session_token(username):
    expire = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=1)
    to_encode = {"sub": username, "exp": expire}
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def get_username_from_token(token):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload.get("sub")
    except Exception:
        return None
    
@app.get("/me")
async def me(request: Request):
    token = request.cookies.get("session")
    username = get_username_from_token(token) if token else None
    if not username:
        raise HTTPException(401, "Not authenticated")
    return {"username": username}

@app.post("/register/options")
async def register_options(request: Request):
    body = await request.json()
    username = body.get("username")
    if not username:
        raise HTTPException(400, "Username required")
    user_id = secrets.token_bytes(16)
    USERS[username] = {"id": user_id, "name": username}
    options = generate_registration_options(
        rp_id=RP_ID,
        rp_name="Example App",
        user_id=user_id,
        user_name=username,
        user_display_name=username,
        authenticator_selection=AuthenticatorSelectionCriteria(user_verification=UserVerificationRequirement.PREFERRED),
        attestation=AttestationConveyancePreference.NONE,
    )
    # Store challenge for verification
    USERS[username]["challenge"] = options.challenge
    return JSONResponse(options_to_json_dict(options))

@app.post("/register/verify")
async def register_verify(request: Request):
    body = await request.json()
    username = body.get("username")
    credential = body.get("credential")
    if not username or not credential:
        raise HTTPException(400, "Missing username or credential")
    user = USERS.get(username)
    if not user:
        raise HTTPException(400, "User not found")
    try:
        verification = verify_registration_response(
            credential=credential,
            expected_challenge=user["challenge"],
            expected_rp_id=RP_ID,
            expected_origin=ORIGIN,
            require_user_verification=True,
        )
        # Store credential public key for authentication
        CREDENTIALS[username] = {
            "credential_id": verification.credential_id,
            "public_key": verification.credential_public_key,
            "sign_count": verification.sign_count,
        }
        return {"verified": True}
    except Exception as e:
        raise HTTPException(400, f"Registration failed: {e}")

@app.post("/authenticate/options")
async def authenticate_options(request: Request):
    body = await request.json()
    username = body.get("username")
    cred = CREDENTIALS.get(username)
    if not cred:
        raise HTTPException(400, "No credential for user")
    options = generate_authentication_options(
        rp_id=RP_ID,
        allow_credentials=[
            PublicKeyCredentialDescriptor(
                id=cred["credential_id"],
                type=PublicKeyCredentialType.PUBLIC_KEY,
            )
        ],
        user_verification=UserVerificationRequirement.PREFERRED,
    )
    USERS[username]["auth_challenge"] = options.challenge
    return JSONResponse(options_to_json_dict(options))

@app.post("/authenticate/verify")
async def authenticate_verify(request: Request):
    body = await request.json()
    username = body.get("username")
    credential = body.get("credential")
    if not username or not credential:
        raise HTTPException(400, "Missing username or credential")
    user = USERS.get(username)
    cred = CREDENTIALS.get(username)
    if not user or not cred:
        raise HTTPException(400, "User or credential not found")
    try:
        verification = verify_authentication_response(
            credential=credential,
            expected_challenge=user["auth_challenge"],
            expected_rp_id=RP_ID,
            expected_origin=ORIGIN,
            credential_public_key=cred["public_key"],
            credential_current_sign_count=cred["sign_count"],
            require_user_verification=True,
        )
        # Update sign count
        cred["sign_count"] = verification.new_sign_count
                # Create session token
        token = create_session_token(username)
        response = JSONResponse({"authenticated": True})
        response.set_cookie(
            key="session",
            value=token,
            httponly=True,
            samesite="lax",
            max_age=60*60*24,  # 1 day
        )
        return response
    except Exception as e:
        raise HTTPException(400, f"Authentication failed: {e}")