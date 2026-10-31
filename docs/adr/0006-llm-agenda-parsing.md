# ADR 0006: Parsing a pasted agenda with an LLM

- Status: accepted
- Date: 2026-10-29

## Context

Organisers paste a free-form agenda (a chat message, an email, meeting notes) and want a
structured agenda: items with an owner and minutes, plus action items with an owner and a
due date. Input is messy, written in Ukrainian or English, and has no fixed format, so
rules and regexes do not cover it. An LLM can turn it into a fixed schema.

## Decision

- **Model:** OpenAI `gpt-5.4-mini` through the Responses API with structured outputs
  (`responses.parse` with a Pydantic model). The model name, reasoning effort and backend
  (`openai` or `fake`) are environment variables, so the model can be swapped without code
  changes. Only `app/ai/agenda.py` knows about the provider.
- **Where it runs:** a separate Lambda (`infra/ai.yml`, function URL) outside the VPC, so
  it can reach the OpenAI API without a NAT gateway. Its role only has `ssm:GetParameter`
  for the API key, stored as an SSM SecureString. It has no access to the database.
- **Auth:** the function verifies the Cognito ID token (signature, issuer, audience,
  `token_use`), so only signed-in users can spend money.
- **Validation:** the response is validated with Pydantic (limits on lengths, minutes and
  dates). On a validation error the call is retried once, then the user gets an error.
- **Human in the loop:** the parser only suggests. The result fills the form, the user
  corrects it and presses Save, which goes through the existing API. The suggestion is
  stored next to the final agenda (`ai_suggestion`), so the difference between the
  suggestion and the saved version is a quality signal.
- **Prompt injection:** the pasted text is treated as data, never as instructions. The
  parser has no tools and no write access, so a malicious text can at worst produce a
  wrong suggestion that the user sees and can fix.
- **Observability:** every call logs one JSON line `agenda_parsed` with model,
  `prompt_version`, input and output tokens, latency and cost.
- **Cost control:** input is limited in size, one retry at most, a budget alarm of $5
  on the AWS account and a spend limit on the OpenAI project.

## Alternatives considered

- **Claude on Amazon Bedrock.** Preferred first, but a new AWS account had zero Bedrock
  token quotas (`ThrottlingException: Too many tokens per day`), and raising them needed
  a support case or a prepayment. Because the provider is hidden behind `parse_agenda`,
  moving back to Bedrock later only means changing that module.
- **Amazon Nova Micro via Converse API.** Same quota problem.
- **Rules and regexes.** Cheap, but fail on free-form and multilingual text.

## Consequences

- Measured on five test inputs: about 460 input and 110 output tokens per request,
  about $0.0008 per request and about 2.3 s average latency.
- A new external dependency and secret (OpenAI key) to rotate.
- The prompt is versioned (`agenda-v1`), so quality changes can be traced to a prompt
  change.
- A different provider can be added later without touching the frontend or the API.
