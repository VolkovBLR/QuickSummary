import os
from enum import Enum

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

load_dotenv()

app = FastAPI(title="Smart Summary API", version="0.2.0")
HF_API_TOKEN = os.getenv("HF_API_TOKEN", "")
HF_API_URL = "https://api-inference.huggingface.co/models/"


class ContentType(str, Enum):
    news = "news"
    technical = "technical"
    scientific = "scientific"
    general = "general"


class SummaryLength(str, Enum):
    short = "short"
    medium = "medium"
    long = "long"


class ClassifyRequest(BaseModel):
    text: str = Field(min_length=20, max_length=30000)


class ClassifyResponse(BaseModel):
    language: str
    content_type: ContentType


class SummarizeRequest(BaseModel):
    text: str = Field(min_length=20, max_length=30000)
    language: str = Field(pattern="^(ru|en)$")
    content_type: ContentType
    summary_length: SummaryLength = SummaryLength.medium
    highlight_key_points: bool = True


class SummarizeResponse(BaseModel):
    language: str
    content_type: ContentType
    summary_length: SummaryLength
    summary: str
    key_points: list[str]
    model_used: str


MODEL_MAP = {
    ContentType.news: "facebook/bart-large-cnn",
    ContentType.technical: "t5-base",
    ContentType.scientific: "google/pegasus-xsum",
    ContentType.general: "facebook/bart-large-cnn",
}

LENGTH_CONFIG = {
    SummaryLength.short: {"max_new_tokens": 80, "min_new_tokens": 30},
    SummaryLength.medium: {"max_new_tokens": 140, "min_new_tokens": 50},
    SummaryLength.long: {"max_new_tokens": 220, "min_new_tokens": 80},
}


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


def detect_language(text: str) -> str:
    cyrillic = sum(1 for ch in text if "\u0400" <= ch <= "\u04FF")
    latin = sum(1 for ch in text if "a" <= ch.lower() <= "z")
    return "ru" if cyrillic >= latin else "en"


def classify_content(text: str) -> ContentType:
    lowered = text.lower()

    scientific_keywords = [
        "abstract", "methodology", "results", "conclusion",
        "исследование", "метод", "результаты", "вывод"
    ]
    technical_keywords = [
        "api", "backend", "frontend", "swift", "python",
        "architecture", "алгоритм", "код", "интеграция", "framework"
    ]
    news_keywords = [
        "breaking", "reported", "government", "today", "yesterday",
        "сегодня", "заявил", "новости", "сообщил"
    ]

    if any(keyword in lowered for keyword in scientific_keywords):
        return ContentType.scientific
    if any(keyword in lowered for keyword in technical_keywords):
        return ContentType.technical
    if any(keyword in lowered for keyword in news_keywords):
        return ContentType.news
    return ContentType.general


def build_prompt(text: str, language: str, content_type: ContentType) -> str:
    if language == "ru":
        prefix = "Сделай краткое и точное резюме текста."
        if content_type == ContentType.news:
            prefix += " Сохрани факты и хронологию."
        elif content_type == ContentType.technical:
            prefix += " Сохрани термины, шаги и технический смысл."
        elif content_type == ContentType.scientific:
            prefix += " Сохрани цель, метод, результаты и выводы."
    else:
        prefix = "Create a concise and accurate summary of the text."
        if content_type == ContentType.news:
            prefix += " Preserve facts and chronology."
        elif content_type == ContentType.technical:
            prefix += " Preserve terminology, steps, and technical meaning."
        elif content_type == ContentType.scientific:
            prefix += " Preserve objective, method, results, and conclusion."

    if content_type == ContentType.technical and language == "en":
        return f"summarize: {text}"

    return f"{prefix}\n\n{text}"


async def call_huggingface(model: str, prompt: str, summary_length: SummaryLength) -> str:
    if not HF_API_TOKEN:
        raise HTTPException(status_code=500, detail="HF_API_TOKEN is not configured")

    headers = {"Authorization": f"Bearer {HF_API_TOKEN}"}
    payload = {
        "inputs": prompt,
        "parameters": {
            **LENGTH_CONFIG[summary_length],
            "do_sample": False,
        },
    }

    async with httpx.AsyncClient(timeout=90) as client:
        response = await client.post(
            f"{HF_API_URL}{model}",
            headers=headers,
            json=payload
        )

    if response.status_code == 503:
        raise HTTPException(
            status_code=503,
            detail="Model is loading on Hugging Face. Try again in a few seconds."
        )

    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail=response.text)

    data = response.json()

    if isinstance(data, list) and data and "summary_text" in data[0]:
        return data[0]["summary_text"].strip()

    if isinstance(data, dict) and "generated_text" in data:
        return data["generated_text"].strip()

    raise HTTPException(status_code=500, detail="Unexpected Hugging Face response")


def extract_key_points(summary: str) -> list[str]:
    candidates = [
        part.strip(" -•\n\t")
        for part in summary.replace(". ", ".\n").splitlines()
    ]
    return [item for item in candidates if len(item) > 15][:5]


@app.post("/classify", response_model=ClassifyResponse)
async def classify(request: ClassifyRequest) -> ClassifyResponse:
    return ClassifyResponse(
        language=detect_language(request.text),
        content_type=classify_content(request.text),
    )


@app.post("/summarize", response_model=SummarizeResponse)
async def summarize(request: SummarizeRequest) -> SummarizeResponse:
    model = MODEL_MAP[request.content_type]
    prompt = build_prompt(request.text, request.language, request.content_type)
    summary = await call_huggingface(model, prompt, request.summary_length)
    key_points = extract_key_points(summary) if request.highlight_key_points else []

    return SummarizeResponse(
        language=request.language,
        content_type=request.content_type,
        summary_length=request.summary_length,
        summary=summary,
        key_points=key_points,
        model_used=model,
    )
