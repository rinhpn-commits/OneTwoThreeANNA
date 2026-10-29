"""Agenda shapes shared by the API and the parser. No AWS or LLM imports in here."""

from datetime import date

from pydantic import BaseModel, Field


class AgendaItem(BaseModel):
    topic: str = Field(min_length=1, max_length=300)
    owner: str | None = Field(default=None, max_length=200)  # a name or an email, as written
    minutes: int | None = Field(default=None, ge=1, le=480)


class ActionItem(BaseModel):
    task: str = Field(min_length=1, max_length=500)
    owner: str | None = Field(default=None, max_length=200)
    due: date | None = None


class Agenda(BaseModel):
    """What is stored on a meeting and what the user saves."""

    items: list[AgendaItem] = Field(default=[], max_length=50)
    action_items: list[ActionItem] = Field(default=[], max_length=50)


class ParsedAgenda(BaseModel):
    """What the model returns: the agenda plus what the text said about the meeting itself."""

    title: str | None = None
    starts_at: str | None = None  # ISO 8601 with the user's offset, if the text says when
    duration_minutes: int | None = Field(default=None, ge=1, le=600)
    items: list[AgendaItem] = Field(max_length=50)
    action_items: list[ActionItem] = Field(default=[], max_length=50)
    language: str  # "uk", "en", ...


class AiSuggestion(BaseModel):
    agenda: ParsedAgenda
    model: str
    prompt_version: str


class AgendaSave(BaseModel):
    agenda: Agenda
    ai_suggestion: AiSuggestion | None = None
