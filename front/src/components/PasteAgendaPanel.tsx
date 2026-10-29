import { useRef, useState } from "react"
import { LoaderCircle } from "lucide-react"

import { Button } from "@/components/ui/button"
import { ParseError, parseAgenda, type ParseResult } from "@/lib/parser"

const MAX_CHARS = 10_000

export function PasteAgendaPanel({ onParsed }: { onParsed: (result: ParseResult) => void }) {
  const [text, setText] = useState("")
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const controller = useRef<AbortController | null>(null)

  const parse = async () => {
    controller.current = new AbortController()
    setBusy(true)
    setError(null)
    try {
      onParsed(await parseAgenda(text, controller.current.signal))
    } catch (err) {
      if ((err as Error).name !== "AbortError") {
        setError(err instanceof ParseError ? err.message : "Could not parse the text")
      }
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="space-y-2">
      <label htmlFor="paste-agenda" className="text-sm font-medium">
        Paste an agenda
      </label>
      <textarea
        id="paste-agenda"
        value={text}
        onChange={(e) => setText(e.target.value)}
        maxLength={MAX_CHARS}
        rows={6}
        disabled={busy}
        placeholder="Paste an email, a chat message or notes…"
        className="w-full rounded-sm border bg-background p-2 text-sm"
      />
      {error && (
        <p role="alert" className="text-sm text-destructive">
          {error} You can always type the agenda by hand.
        </p>
      )}
      {busy ? (
        <div className="flex items-center gap-3 text-sm text-muted-foreground">
          <LoaderCircle className="size-4 animate-spin" /> Reading your text, this takes a few
          seconds…
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => controller.current?.abort()}
          >
            Cancel
          </Button>
        </div>
      ) : (
        <Button type="button" onClick={parse} disabled={!text.trim()}>
          Parse
        </Button>
      )}
    </div>
  )
}
