"""Report builder Lambda: started by the schedule, an SQS message, or by hand."""

import json
import logging
import os

import boto3

from app.reports.weekly import build_weekly_report, previous_iso_week

log = logging.getLogger()
log.setLevel(logging.INFO)


def _parse(event: dict) -> tuple[str, dict, str]:
    """Return (trigger, payload, detail). Handles an SQS event and a direct invocation."""
    records = event.get("Records") or []
    if records and records[0].get("eventSource") == "aws:sqs":
        record = records[0]
        detail = (
            f"messageId={record['messageId']} "
            f"receiveCount={record['attributes']['ApproximateReceiveCount']}"
        )
        return "sqs", json.loads(record["body"] or "{}"), detail
    return event.get("source", "invoke"), event, ""


def handler(event, context):
    trigger, payload, detail = _parse(event)
    week = payload.get("week") or previous_iso_week()
    log.info(
        "report-builder triggered trigger=%s week=%s requested_by=%s %s",
        trigger, week, payload.get("source"), detail,
    )
    if week == os.environ.get("FAIL_WEEK"):
        raise RuntimeError(f"FAIL_WEEK={week}: failing on purpose (DLQ test)")

    body = build_weekly_report(week)
    key = f"reports/{week}.csv"  # same week, same key: running twice overwrites
    boto3.client("s3").put_object(
        Bucket=os.environ["REPORTS_BUCKET"], Key=key, Body=body, ContentType="text/csv"
    )
    log.info("report-builder saved key=%s bytes=%d", key, len(body))
    return {"week": week, "key": key}
