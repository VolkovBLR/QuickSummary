import os
from pathlib import Path
from enum import Enum

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

app = FastAPI(title="Quick Summary API", version="1.1.0")

HF_API_TOKEN = os.getenv("HF_API_TOKEN", "").strip()
HF_API_URL = "https://router.huggingface.co/hf-inference/models/"


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
    model_config = {"protected_namespaces": ()}

    language: str
    content_type: ContentType
    summary_length: SummaryLength
    summary: str
    key_points: list[str]
    model_used: str


LENGTH_CONFIG = {
    SummaryLength.short: {"max_new_tokens": 60, "min_new_tokens": 20},
    SummaryLength.medium: {"max_new_tokens": 120, "min_new_tokens": 35},
    SummaryLength.long: {"max_new_tokens": 180, "min_new_tokens": 50},
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
        "abstract", "methodology", "results", "conclusion", "hypothesis",
        "исследование", "метод", "результаты", "вывод", "гипотеза", "эксперимент"
    ]
    technical_keywords = [
        "api", "backend", "frontend", "swift", "python", "architecture",
        "framework", "database", "integration", "алгоритм", "код", "интеграция",
        "архитектура", "база данных", "фреймворк"
    ]
    news_keywords = [
        "breaking", "reported", "government", "today", "yesterday",
        "announced", "official", "сегодня", "вчера", "заявил", "сообщил",
        "правительство", "официально", "новости"
    ]

    if any(keyword in lowered for keyword in scientific_keywords):
        return ContentType.scientific
    if any(keyword in lowered for keyword in technical_keywords):
        return ContentType.technical
    if any(keyword in lowered for keyword in news_keywords):
        return ContentType.news
    return ContentType.general


def choose_model(language: str, content_type: ContentType) -> str:
    if language == "ru":
        return "RussianNLP/FRED-T5-Summarizer"
    return "facebook/bart-large-cnn"


def normalize_input_text(text: str, language: str) -> str:
    cleaned = " ".join(text.split())
    max_chars = 1800 if language == "ru" else 2500
    return cleaned[:max_chars]


def build_input_text(text: str, language: str, model: str) -> str:
    cleaned = normalize_input_text(text, language)

    if model == "RussianNLP/FRED-T5-Summarizer":
        return f"<LM>{cleaned}"

    return cleaned


async def call_huggingface(model: str, input_text: str, summary_length: SummaryLength) -> str:
    if not HF_API_TOKEN:
        raise HTTPException(status_code=500, detail="HF_API_TOKEN is not configured")

    headers = {
        "Authorization": f"Bearer {HF_API_TOKEN}",
        "Content-Type": "application/json",
    }

    payload = {
        "inputs": input_text,
        "parameters": {
            **LENGTH_CONFIG[summary_length],
            "do_sample": False
        },
        "options": {
            "wait_for_model": True
        }
    }

    async with httpx.AsyncClient(timeout=120) as client:
        response = await client.post(
            f"{HF_API_URL}{model}",
            headers=headers,
            json=payload
        )

    print("HF STATUS:", response.status_code)
    print("HF BODY:", response.text)

    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail=response.text)

    data = response.json()

    if isinstance(data, list) and data:
        item = data[0]
        if isinstance(item, dict):
            if "summary_text" in item:
                return item["summary_text"].strip()
            if "generated_text" in item:
                return item["generated_text"].strip()

    if isinstance(data, dict):
        if "summary_text" in data:
            return data["summary_text"].strip()
        if "generated_text" in data:
            return data["generated_text"].strip()

    raise HTTPException(status_code=500, detail=f"Unexpected Hugging Face response: {data}")


def extract_key_points(summary: str) -> list[str]:
    parts = [
        part.strip(" -•\n\t")
        for part in summary.replace(". ", ".\n").splitlines()
    ]
    points = [part for part in parts if len(part) > 18]
    return points[:5]


@app.post("/classify", response_model=ClassifyResponse)
async def classify(request: ClassifyRequest) -> ClassifyResponse:
    return ClassifyResponse(
        language=detect_language(request.text),
        content_type=classify_content(request.text)
    )


@app.post("/summarize", response_model=SummarizeResponse)
async def summarize(request: SummarizeRequest) -> SummarizeResponse:
    model = choose_model(request.language, request.content_type)
    input_text = build_input_text(request.text, request.language, model)
    summary = await call_huggingface(model, input_text, request.summary_length)
    key_points = extract_key_points(summary) if request.highlight_key_points else []

    return SummarizeResponse(
        language=request.language,
        content_type=request.content_type,
        summary_length=request.summary_length,
        summary=summary,
        key_points=key_points,
        model_used=model
    )
