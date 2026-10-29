import { getIdToken } from "@/lib/auth"
import type { ParseResult } from "@/types"

export type { ParseResult } from "@/types"

export class ParseError extends Error {
  readonly status: number
  constructor(status: number, message: string) {
    super(message)
    this.status = status
  }
}

const MESSAGES: Record<number, string> = {
  401: "Your session expired, sign in again",
  413: "The text is too long (limit 10,000 characters)",
  422: "I could not find an agenda in this text",
  429: "The AI service is busy, try again in a minute",
  502: "The AI service failed, type the agenda by hand",
  503: "The AI service is unavailable, type the agenda by hand",
}

export async function parseAgenda(text: string, signal?: AbortSignal): Promise<ParseResult> {
  const url = import.meta.env.VITE_PARSER_URL
  if (!url) throw new ParseError(0, "The parser is not configured")
  const token = await getIdToken()
  let response: Response
  try {
    response = await fetch(url, {
      method: "POST",
      signal,
      headers: {
        "content-type": "application/json",
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify({
        text,
        // the user's "Monday" is in the user's time zone, not the Lambda's (UTC)
        today: new Date().toLocaleDateString("sv-SE"),
        tz: Intl.DateTimeFormat().resolvedOptions().timeZone,
      }),
    })
  } catch (error) {
    if ((error as Error).name === "AbortError") throw error
    throw new ParseError(0, "Network error, check your connection")
  }
  const data = await response.json().catch(() => ({}))
  if (!response.ok) {
    throw new ParseError(
      response.status,
      MESSAGES[response.status] ?? data.error ?? "Could not parse the text",
    )
  }
  return data as ParseResult
}
