"""Run from the repository root: uvicorn service.main:app --reload."""

import json
import os
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Annotated
from uuid import UUID

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from httpx import HTTPError
from postgrest.exceptions import APIError
from pydantic import BaseModel, ConfigDict, StrictBool
from supabase import ClientOptions, create_client
from supabase_auth.errors import AuthApiError, AuthRetryableError


METHOD_VERSION = "survey-count-v1"
LIMITATIONS = (
    "Unvalidated survey summary only. The score counts reported symptoms; it is "
    "not a PCOS probability, diagnosis, or clinical risk classification. Missing "
    "answers are unknown. Symptoms or their absence cannot confirm or rule out "
    "PCOS. Discuss concerns with a qualified healthcare professional."
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    load_dotenv(Path(__file__).resolve().parents[1] / ".env")
    url = os.getenv("SUPABASE_URL", "").strip()
    key = os.getenv("SUPABASE_ANON_KEY", "").strip()
    if not url or not key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_ANON_KEY must be configured.")
    app.state.supabase_url = url
    app.state.supabase_key = key
    yield


app = FastAPI(title="PCOS Survey API", lifespan=lifespan)
bearer = HTTPBearer(auto_error=False)


class SurveyData(BaseModel):
    model_config = ConfigDict(extra="forbid")

    irregular_periods: StrictBool | None = None
    acne: StrictBool | None = None
    excess_hair_growth: StrictBool | None = None
    scalp_hair_thinning: StrictBool | None = None


class Prediction(BaseModel):
    assessment_id: UUID
    prediction: str
    risk_score: int
    answered_questions: int
    total_questions: int
    reported_symptoms: list[str]
    method_version: str
    limitations: str


@app.exception_handler(RequestValidationError)
async def invalid_request(request: Request, exc: RequestValidationError):
    # FastAPI's default errors echo submitted values, including private data.
    return JSONResponse(
        status_code=422,
        content={"detail": "Provide only the documented survey fields as booleans or null."},
        headers={"Cache-Control": "no-store"},
    )


@app.middleware("http")
async def private_responses(request: Request, call_next):
    response = await call_next(request)
    response.headers["Cache-Control"] = "no-store"
    return response


@app.post("/predict-pcos", response_model=Prediction, status_code=201)
def predict_pcos(
    survey: SurveyData,
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
):
    if credentials is None:
        raise HTTPException(401, "A Supabase access token is required.", headers={"WWW-Authenticate": "Bearer"})

    # Never mutate a shared client's auth state across concurrent users.
    client = create_client(
        request.app.state.supabase_url,
        request.app.state.supabase_key,
        options=ClientOptions(persist_session=False, auto_refresh_token=False),
    )
    token = credentials.credentials
    try:
        auth = client.auth.get_user(token)
    except AuthApiError:
        raise HTTPException(401, "Invalid or expired access token.", headers={"WWW-Authenticate": "Bearer"}) from None
    except (HTTPError, AuthRetryableError):
        raise HTTPException(503, "Authentication is temporarily unavailable.") from None
    if auth is None or auth.user is None:
        raise HTTPException(401, "Invalid or expired access token.")
    client.postgrest.auth(token)

    answers = survey.model_dump()
    answered = sum(value is not None for value in answers.values())
    if not answered:
        raise HTTPException(422, "Answer at least one survey question.")
    symptoms = [name for name, value in answers.items() if value is True]
    # Equal-weight count only: no invented clinical thresholds or percentages.
    summary = {
        "prediction": "insufficient_data" if answered < len(answers) else "survey_summary",
        "risk_score": len(symptoms),
        "answered_questions": answered,
        "total_questions": len(answers),
        "reported_symptoms": symptoms,
        "method_version": METHOD_VERSION,
        "limitations": LIMITATIONS,
    }
    try:
        result = client.table("pcos_assessments").insert({
            "user_id": str(auth.user.id),
            "assessment_date": datetime.now(timezone.utc).date().isoformat(),
            "status": "draft",
            "observations": json.dumps({"survey": answers, "summary": summary}),
            "limitations": LIMITATIONS,
            "method_version": METHOD_VERSION,
        }).execute()
    except (APIError, HTTPError):
        raise HTTPException(503, "Assessment could not be saved. Please try again.") from None
    if not result.data:
        raise HTTPException(503, "Assessment could not be saved.")
    return Prediction(assessment_id=result.data[0]["id"], **summary)
