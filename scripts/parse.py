import json
import os
import sys
from datetime import date

sys.path.insert(0, "back")
from app.ai.agenda import cost_usd, parse_agenda  # noqa: E402

arg = sys.argv[1]
text = open(arg, encoding="utf-8").read() if os.path.exists(arg) else arg
agenda, usage = parse_agenda(text, date.today(), "Europe/Kyiv")
print(json.dumps(agenda.model_dump(mode="json"), ensure_ascii=False, indent=2))
model = os.environ.get("PARSER_MODEL", "gpt-5.4-mini")
print(usage, "cost $", cost_usd(model, usage))
