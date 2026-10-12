"""Weekly meetings report: the CSV for one ISO week."""

import csv
import io
import re
from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.db import SessionLocal  # <- ПЕРЕВІРТЕ ім'я модуля і сесії за grep вище
from app.models import Meeting

WEEK_RE = re.compile(r"^(\d{4})-W(\d{2})$")


def iso_week_of(day: date) -> str:
    year, week, _ = day.isocalendar()
    return f"{year}-W{week:02d}"


def previous_iso_week(today: date | None = None) -> str:
    """The week before the one `today` is in (the schedule never names a week itself)."""
    today = today or datetime.now(timezone.utc).date()
    return iso_week_of(today - timedelta(days=7))


def week_bounds(week: str) -> tuple[datetime, datetime]:
    """Monday 00:00 UTC (inclusive) to the next Monday (exclusive)."""
    match = WEEK_RE.match(week)
    if not match:
        raise ValueError(f"Bad week {week!r}, expected e.g. 2026-W40")
    monday = date.fromisocalendar(int(match[1]), int(match[2]), 1)
    start = datetime.combine(monday, time.min, tzinfo=timezone.utc)
    return start, start + timedelta(days=7)


def _hours(meeting: Meeting) -> float:
    return (meeting.ends_at - meeting.starts_at).total_seconds() / 3600


def _meetings(session, start: datetime, end: datetime) -> list[Meeting]:
    stmt = (
        select(Meeting)
        .options(selectinload(Meeting.participants))
        .where(Meeting.starts_at >= start, Meeting.starts_at < end)
        .order_by(Meeting.starts_at)
    )
    return list(session.scalars(stmt))


def build_weekly_report(week: str) -> bytes:
    """Return the CSV of one ISO week, e.g. "2026-W40". The same week gives the same file."""
    start, end = week_bounds(week)
    prev_start = start - timedelta(days=7)
    prev_week = iso_week_of(prev_start.date())

    with SessionLocal() as session:
        current = _meetings(session, start, end)
        previous = _meetings(session, prev_start, start)
        top = sorted(current, key=_hours, reverse=True)[:5]
        top_rows = [
            ("top_meeting", m.title, f"{_hours(m):.2f}", m.starts_at.isoformat(), len(m.participants))
            for m in top
        ]

    cur_count, cur_hours = len(current), sum(_hours(m) for m in current)
    prev_count, prev_hours = len(previous), sum(_hours(m) for m in previous)

    out = io.StringIO()
    writer = csv.writer(out)
    writer.writerow(["section", "label", "value", "start", "participants"])
    writer.writerow(["summary", "week", week, "", ""])
    writer.writerow(["summary", "meetings", cur_count, "", ""])
    writer.writerow(["summary", "total_hours", f"{cur_hours:.2f}", "", ""])
    writer.writerow(["previous_week", "week", prev_week, "", ""])
    writer.writerow(["previous_week", "meetings", prev_count, "", ""])
    writer.writerow(["previous_week", "total_hours", f"{prev_hours:.2f}", "", ""])
    writer.writerow(["change", "meetings", f"{cur_count - prev_count:+d}", "", ""])
    writer.writerow(["change", "total_hours", f"{cur_hours - prev_hours:+.2f}", "", ""])
    writer.writerows(top_rows)  # label = title, value = duration in hours
    return out.getvalue().encode("utf-8-sig")  # BOM: Excel opens Ukrainian titles correctly
