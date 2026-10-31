"""Agenda parser Lambda behind a function URL: pasted text in, a structured agenda out."""

import base64
import json
import logging
import os
import time
from datetime import date

import jwt
import openai
from jwt import PyJWKSet

from app.ai.agenda import PROMPT_VERSION, AgendaParseError, cost_usd, parse_agenda

log = logging.getLogger()
log.setLevel(logging.INFO)

MODEL = os.environ["PARSER_MODEL"]
MAX_CHARS = int(os.environ.get("MAX_TEXT_CHARS", "10000"))
REGION = os.environ["COGNITO_REGION"]
POOL_ID = os.environ["COGNITO_USER_POOL_ID"]
CLIENT_ID = os.environ["COGNITO_CLIENT_ID"]
ISSUER = f"https://cognito-idp.{REGION}.amazonaws.com/{POOL_ID}"
JWKS = PyJWKSet.from_dict(json.loads(os.environ["COGNITO_JWKS"]))  # cached for the container's life


def _verify(token: str) -> dict:
    """Signature, expiry, issuer and audience. Raises on anything wrong."""
    kid = jwt.get_unverified_header(token)["kid"]
    claims = jwt.decode(
        token,
        JWKS[kid].key,
        algorithms=["RS256"],
        issuer=ISSUER,
        audience=CLIENT_ID,
        options={"require": ["exp", "iss", "aud"]},
    )
    if claims.get("token_use") != "id":
        raise ValueError("not an ID token")
    return claims


def _response(status: int, payload: dict) -> dict:
    return {
        "statusCode": status,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(payload, ensure_ascii=False),
    }


def handler(event, context):
    headers = event.get("headers") or {}
    token = headers.get("authorization", "").removeprefix("Bearer ").strip()
    try:
        claims = _verify(token)
    except Exception:
        return _response(401, {"error": "unauthorized"})

    try:
        raw = event.get("body") or "{}"
        if event.get("isBase64Encoded"):
            raw = base64.b64decode(raw).decode("utf-8")
        body = json.loads(raw)
        text = body["text"]
        today = date.fromisoformat(body["today"])
        tz = str(body["tz"])
    except (KeyError, ValueError, TypeError):
        return _response(400, {"error": "expected JSON with text, today (YYYY-MM-DD) and tz"})
    if not isinstance(text, str) or not text.strip():
        return _response(400, {"error": "text is empty"})
    if len(text) > MAX_CHARS:
        return _response(413, {"error": f"text is longer than {MAX_CHARS} characters"})

    started = time.monotonic()
    try:
        agenda, usage = parse_agenda(text, today, tz)
    except AgendaParseError as e:
        return _response(422, {"error": str(e)})
    except openai.RateLimitError as e:
        if getattr(e, "code", None) == "insufficient_quota":  # the balance is empty
            log.error("OpenAI balance is empty: top up in platform.openai.com/billing")
            return _response(503, {"error": "the AI service is unavailable"})
        return _response(429, {"error": "the AI service is busy, try again in a minute"})
    except openai.APIError:
        log.exception("openai call failed")
        return _response(502, {"error": "the AI service failed"})

    log.info(
        json.dumps(
            {
                "event": "agenda_parsed",
                "user": claims["sub"],
                "model": MODEL,
                "prompt_version": PROMPT_VERSION,
                **usage,
                "latency_ms": int((time.monotonic() - started) * 1000),
                "cost_usd": cost_usd(MODEL, usage),
            }
        )
    )
    return _response(
        200,
        {"agenda": agenda.model_dump(mode="json"), "model": MODEL, "prompt_version": PROMPT_VERSION},
    )
