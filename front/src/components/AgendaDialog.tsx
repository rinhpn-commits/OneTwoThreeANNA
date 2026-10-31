import { useState, type ReactNode } from "react"
import { Plus, Trash2 } from "lucide-react"
import { toast } from "sonner"

import { PasteAgendaPanel } from "@/components/PasteAgendaPanel"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { useSaveAgenda } from "@/hooks/useMeetings"
import type { Agenda, Meeting, ParseResult } from "@/types"

interface ItemRow {
  id: string
  topic: string
  owner: string
  minutes: string
}
interface ActionRow {
  id: string
  task: string
  owner: string
  due: string
}
interface Rows {
  items: ItemRow[]
  actions: ActionRow[]
}

const newId = () => crypto.randomUUID()

function toRows(agenda: Agenda | null | undefined): Rows {
  return {
    items: (agenda?.items ?? []).map((i) => ({
      id: newId(),
      topic: i.topic,
      owner: i.owner ?? "",
      minutes: i.minutes?.toString() ?? "",
    })),
    actions: (agenda?.action_items ?? []).map((a) => ({
      id: newId(),
      task: a.task,
      owner: a.owner ?? "",
      due: a.due ?? "",
    })),
  }
}

/** Keys of the fields the model filled; they get a "suggested" badge until touched. */
function suggestedKeys(rows: Rows): Set<string> {
  const keys = new Set<string>()
  for (const r of rows.items) {
    if (r.topic) keys.add(`${r.id}.topic`)
    if (r.owner) keys.add(`${r.id}.owner`)
    if (r.minutes) keys.add(`${r.id}.minutes`)
  }
  for (const r of rows.actions) {
    if (r.task) keys.add(`${r.id}.task`)
    if (r.owner) keys.add(`${r.id}.owner`)
    if (r.due) keys.add(`${r.id}.due`)
  }
  return keys
}

function Flagged({ on, children }: { on: boolean; children: ReactNode }) {
  return (
    <div className="space-y-0.5">
      {children}
      {on && (
        <span className="block text-[10px] tracking-wide text-brand uppercase">suggested</span>
      )}
    </div>
  )
}

function AgendaEditor({ meeting, onClose }: { meeting: Meeting; onClose: () => void }) {
  const saveAgenda = useSaveAgenda()
  const [rows, setRows] = useState<Rows>(() => toRows(meeting.agenda))
  const [suggested, setSuggested] = useState<Set<string>>(new Set())
  const [suggestion, setSuggestion] = useState<ParseResult | null>(null)

  const unmark = (key: string) =>
    setSuggested((prev) => {
      if (!prev.has(key)) return prev
      const next = new Set(prev)
      next.delete(key)
      return next
    })

  const editItem = (id: string, field: "topic" | "owner" | "minutes", value: string) => {
    setRows((r) => ({
      ...r,
      items: r.items.map((x) => (x.id === id ? { ...x, [field]: value } : x)),
    }))
    unmark(`${id}.${field}`)
  }
  const editAction = (id: string, field: "task" | "owner" | "due", value: string) => {
    setRows((r) => ({
      ...r,
      actions: r.actions.map((x) => (x.id === id ? { ...x, [field]: value } : x)),
    }))
    unmark(`${id}.${field}`)
  }

  const onParsed = (result: ParseResult) => {
    const next = toRows(result.agenda)
    setRows(next)
    setSuggested(suggestedKeys(next))
    setSuggestion(result)
    if (next.items.length === 0 && next.actions.length === 0) {
      toast.info("No agenda found in this text. You can type one by hand.")
    }
  }

  const save = async () => {
    for (const r of rows.items) {
      const minutes = Number(r.minutes)
      if (r.minutes && !(Number.isInteger(minutes) && minutes >= 1 && minutes <= 480)) {
        toast.error("Minutes must be a whole number from 1 to 480")
        return
      }
    }
    const agenda: Agenda = {
      items: rows.items
        .filter((r) => r.topic.trim())
        .map((r) => ({
          topic: r.topic.trim(),
          owner: r.owner.trim() || null,
          minutes: r.minutes ? Number(r.minutes) : null,
        })),
      action_items: rows.actions
        .filter((r) => r.task.trim())
        .map((r) => ({ task: r.task.trim(), owner: r.owner.trim() || null, due: r.due || null })),
    }
    try {
      // The suggestion travels with the final agenda: the difference is the quality signal.
      await saveAgenda.mutateAsync({ id: meeting.id, data: { agenda, ai_suggestion: suggestion } })
      toast.success("Agenda saved")
      onClose()
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Could not save the agenda")
    }
  }

  return (
    <>
      <DialogHeader>
        <DialogTitle>Agenda</DialogTitle>
        <DialogDescription>{meeting.title}</DialogDescription>
      </DialogHeader>

      <PasteAgendaPanel onParsed={onParsed} />

      <section className="space-y-2">
        <h3 className="text-sm font-medium">Agenda items</h3>
        {rows.items.map((r) => (
          <div key={r.id} className="grid grid-cols-[1fr_9rem_5rem_auto] items-start gap-2">
            <Flagged on={suggested.has(`${r.id}.topic`)}>
              <Input
                aria-label="Topic"
                placeholder="Topic"
                value={r.topic}
                onChange={(e) => editItem(r.id, "topic", e.target.value)}
              />
            </Flagged>
            <Flagged on={suggested.has(`${r.id}.owner`)}>
              <Input
                aria-label="Owner"
                placeholder="Owner"
                value={r.owner}
                onChange={(e) => editItem(r.id, "owner", e.target.value)}
              />
            </Flagged>
            <Flagged on={suggested.has(`${r.id}.minutes`)}>
              <Input
                aria-label="Minutes"
                type="number"
                min={1}
                max={480}
                placeholder="min"
                value={r.minutes}
                onChange={(e) => editItem(r.id, "minutes", e.target.value)}
              />
            </Flagged>
            <Button
              type="button"
              variant="ghost"
              size="icon"
              aria-label="Remove item"
              onClick={() =>
                setRows((x) => ({ ...x, items: x.items.filter((i) => i.id !== r.id) }))
              }
            >
              <Trash2 className="size-4" />
            </Button>
          </div>
        ))}
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() =>
            setRows((x) => ({
              ...x,
              items: [...x.items, { id: newId(), topic: "", owner: "", minutes: "" }],
            }))
          }
        >
          <Plus className="size-4" /> Add item
        </Button>
      </section>

      <section className="space-y-2">
        <h3 className="text-sm font-medium">Action items</h3>
        {rows.actions.map((r) => (
          <div key={r.id} className="grid grid-cols-[1fr_9rem_9rem_auto] items-start gap-2">
            <Flagged on={suggested.has(`${r.id}.task`)}>
              <Input
                aria-label="Task"
                placeholder="Task"
                value={r.task}
                onChange={(e) => editAction(r.id, "task", e.target.value)}
              />
            </Flagged>
            <Flagged on={suggested.has(`${r.id}.owner`)}>
              <Input
                aria-label="Owner"
                placeholder="Owner"
                value={r.owner}
                onChange={(e) => editAction(r.id, "owner", e.target.value)}
              />
            </Flagged>
            <Flagged on={suggested.has(`${r.id}.due`)}>
              <Input
                aria-label="Due date"
                type="date"
                value={r.due}
                onChange={(e) => editAction(r.id, "due", e.target.value)}
              />
            </Flagged>
            <Button
              type="button"
              variant="ghost"
              size="icon"
              aria-label="Remove action item"
              onClick={() =>
                setRows((x) => ({ ...x, actions: x.actions.filter((a) => a.id !== r.id) }))
              }
            >
              <Trash2 className="size-4" />
            </Button>
          </div>
        ))}
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() =>
            setRows((x) => ({
              ...x,
              actions: [...x.actions, { id: newId(), task: "", owner: "", due: "" }],
            }))
          }
        >
          <Plus className="size-4" /> Add action item
        </Button>
      </section>

      <DialogFooter>
        <Button type="button" variant="outline" onClick={onClose}>
          Cancel
        </Button>
        <Button type="button" onClick={save} disabled={saveAgenda.isPending}>
          {saveAgenda.isPending ? "Saving…" : "Save agenda"}
        </Button>
      </DialogFooter>
    </>
  )
}

export function AgendaDialog({
  meeting,
  onOpenChange,
}: {
  meeting: Meeting | null
  onOpenChange: (open: boolean) => void
}) {
  return (
    <Dialog open={meeting !== null} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90vh] space-y-4 overflow-y-auto sm:max-w-2xl">
        {meeting && (
          <AgendaEditor key={meeting.id} meeting={meeting} onClose={() => onOpenChange(false)} />
        )}
      </DialogContent>
    </Dialog>
  )
}
