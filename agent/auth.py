"""Cognito JWT verification and FastAPI current-user dependency."""
import os
from typing import Annotated

import jwt
from jwt import PyJWKClient
from dotenv import load_dotenv
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from database import User, engine, get_or_create_user_by_cognito

load_dotenv()

_REGION       = os.getenv("COGNITO_REGION", "")
_USER_POOL_ID = os.getenv("COGNITO_USER_POOL_ID", "")
_CLIENT_ID    = os.getenv("COGNITO_CLIENT_ID", "")

_ISSUER   = f"https://cognito-idp.{_REGION}.amazonaws.com/{_USER_POOL_ID}"
_JWKS_URI = f"{_ISSUER}/.well-known/jwks.json"

# Module-level client; fetches + caches public keys lazily on first use.
_jwks_client = PyJWKClient(_JWKS_URI) if _REGION and _USER_POOL_ID else None

_bearer = HTTPBearer()


def verify_id_token(token: str) -> dict:
    """Verify a Cognito ID token; raise HTTP 401 on any failure."""
    if _jwks_client is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Cognito not configured (missing env vars)",
        )
    try:
        signing_key = _jwks_client.get_signing_key_from_jwt(token)
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience=_CLIENT_ID,
            issuer=_ISSUER,
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expired")
    except jwt.InvalidTokenError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc))

    if payload.get("token_use") != "id":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not an ID token")

    return payload


def current_user(
    creds: Annotated[HTTPAuthorizationCredentials, Depends(_bearer)],
) -> User:
    """FastAPI dependency: verify Bearer token and return (or JIT-create) service User."""
    payload = verify_id_token(creds.credentials)
    sub   = payload["sub"]
    email = payload.get("email", "")
    name  = payload.get("name") or payload.get("cognito:username") or email
    try:
        with Session(engine) as session:
            return get_or_create_user_by_cognito(session, sub, email, name)
    except IntegrityError:
        # Race condition: another request just created the row; fetch it
        with Session(engine) as session:
            return session.query(User).filter(User.cognito_sub == sub).one()
