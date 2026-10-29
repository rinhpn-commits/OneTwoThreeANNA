import os

from openai import OpenAI

client = OpenAI()  # reads OPENAI_API_KEY
response = client.responses.create(
    model=os.environ.get("PARSER_MODEL", "gpt-5.4-mini"),
    input="In one sentence: what is an ISO week?",
)
print(response.output_text)
print(response.status, response.usage.input_tokens, response.usage.output_tokens)
