import { useState, useEffect, useMemo } from "react"
import { useNavigate } from "react-router-dom"
import { Button } from "../components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "../components/ui/dialog"
import { Input } from "../components/ui/input"
import { Label } from "../components/ui/label"
import { listCredentials, createCredential, getCredentialSecret, deleteCredential, generatePassword, credentialTypeLabel } from "../api/client"
import type { Credential } from "../api/client"
import { useVaultSealed } from "../hooks/useVaultSealed"
import { Plus, Trash2, Eye, Search, Copy } from "lucide-react"

const UNGROUPED_LABEL = "— No category —"
const CREDENTIAL_TYPES = [
  { value: "", label: "All" },
  { value: "password", label: "Password" },
  { value: "ssh_key", label: "SSH key" },
  { value: "api_key", label: "API key" },
  { value: "other", label: "Other" },
] as const

export function CredentialsPage() {
  const { sealed, loading: vaultLoading } = useVaultSealed()
  const navigate = useNavigate()
  const [items, setItems] = useState<Credential[]>([])
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState("")
  const [typeFilter, setTypeFilter] = useState("")
  const [categoryFilter, setCategoryFilter] = useState<string>("")
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState({ type: "password", name: "", username: "", category: "", description: "", secret: "" })
  const [copyFeedback, setCopyFeedback] = useState<{ id: number; kind: "password" | "username" } | null>(null)
  const [holdingRevealId, setHoldingRevealId] = useState<number | null>(null)
  const [secretCache, setSecretCache] = useState<Record<number, string>>({})
  const [deleteConfirm, setDeleteConfirm] = useState<{ id: number; name: string } | null>(null)
  const [deleting, setDeleting] = useState(false)

  const load = () => {
    setLoading(true)
    listCredentials(typeFilter || undefined, undefined)
      .then(setItems)
      .catch((err) => alert(err instanceof Error ? err.message : "Could not load credentials."))
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    if (!vaultLoading && sealed) {
      navigate("/unseal", { replace: true })
      return
    }
    if (!sealed) load()
  }, [typeFilter, sealed, vaultLoading, navigate])

  const categories = useMemo(() => {
    const cats = Array.from(
      new Set(items.map((c) => (c.category?.trim() ? c.category.trim() : UNGROUPED_LABEL)))
    ).sort((a, b) => {
      if (a === UNGROUPED_LABEL) return 1
      if (b === UNGROUPED_LABEL) return -1
      return a.localeCompare(b)
    })
    return cats
  }, [items])

  const filteredItems = useMemo(() => {
    let list = items
    if (categoryFilter && categoryFilter !== "") {
      list = categoryFilter === UNGROUPED_LABEL
        ? items.filter((c) => !c.category?.trim())
        : items.filter((c) => (c.category?.trim() || UNGROUPED_LABEL) === categoryFilter)
    }
    const q = searchQuery.trim().toLowerCase()
    if (!q) return list
    return list.filter(
      (c) =>
        c.name.toLowerCase().includes(q) ||
        (c.username?.toLowerCase().includes(q)) ||
        (c.description?.toLowerCase().includes(q)) ||
        (c.category?.toLowerCase().includes(q))
    )
  }, [items, categoryFilter, searchQuery])

  if (!vaultLoading && sealed) return null

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!form.name.trim() || !form.secret.trim()) return
    try {
      await createCredential({
        type: form.type,
        name: form.name.trim(),
        username: form.username.trim() || undefined,
        category: form.category.trim() || undefined,
        description: form.description.trim() || undefined,
        secret: form.secret,
      })
      setForm({ type: "password", name: "", username: "", category: "", description: "", secret: "" })
      setShowForm(false)
      load()
    } catch (err) {
      alert(err instanceof Error ? err.message : "Error")
    }
  }

  const loadSecretForReveal = async (id: number) => {
    if (secretCache[id]) return
    try {
      const secret = await getCredentialSecret(id)
      setSecretCache((c) => ({ ...c, [id]: secret }))
    } catch (err) {
      alert(err instanceof Error ? err.message : "Could not load secret.")
    }
  }

  const handleRevealPointerDown = (id: number) => {
    loadSecretForReveal(id).then(() => setHoldingRevealId(id))
  }

  const handleRevealPointerUp = () => {
    setHoldingRevealId(null)
  }

  const doGenerate = () => {
    generatePassword().then((p) => setForm((f) => ({ ...f, secret: p })))
  }

  const copyToClipboard = async (id: number, text: string, kind: "password" | "username") => {
    if (!text) return
    try {
      await navigator.clipboard.writeText(text)
      setCopyFeedback({ id, kind })
      setTimeout(() => setCopyFeedback(null), 1500)
    } catch {
      alert("Could not copy to clipboard.")
    }
  }

  const copyPassword = async (c: Credential) => {
    let secret = secretCache[c.id]
    if (secret === undefined) {
      try {
        secret = await getCredentialSecret(c.id)
        setSecretCache((prev) => ({ ...prev, [c.id]: secret }))
      } catch {
        alert("Could not load secret.")
        return
      }
    }
    await copyToClipboard(c.id, secret, "password")
  }

  const handleConfirmDelete = async () => {
    if (!deleteConfirm) return
    setDeleting(true)
    try {
      await deleteCredential(deleteConfirm.id)
      setDeleteConfirm(null)
      load()
    } finally {
      setDeleting(false)
    }
  }

  return (
    <div className="space-y-6">
      {/* Header + Add */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <h1 className="text-2xl font-semibold">Credentials</h1>
        <Button onClick={() => setShowForm(!showForm)}>
          <Plus className="mr-2 h-4 w-4" />
          Add new
        </Button>
      </div>

      {/* Top bar: search + type + categories */}
      <div className="rounded-lg border bg-card p-4 space-y-4">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:gap-4">
          <div className="relative flex-1 min-w-0">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground pointer-events-none" />
            <Input
              placeholder="Search by name, username, description, or category…"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9 bg-background"
            />
          </div>
          <div className="flex flex-wrap gap-2 shrink-0">
            {CREDENTIAL_TYPES.map(({ value, label }) => (
              <Button
                key={value || "all"}
                variant={typeFilter === value ? "default" : "outline"}
                size="sm"
                onClick={() => setTypeFilter(value)}
              >
                {label}
              </Button>
            ))}
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-sm font-medium text-muted-foreground shrink-0">Category:</span>
          <Button
            variant={categoryFilter === "" ? "secondary" : "ghost"}
            size="sm"
            onClick={() => setCategoryFilter("")}
            className="rounded-full"
          >
            All
          </Button>
          {categories.map((cat) => (
            <Button
              key={cat}
              variant={categoryFilter === cat ? "secondary" : "ghost"}
              size="sm"
              onClick={() => setCategoryFilter(cat)}
              className="rounded-full"
            >
              {cat === UNGROUPED_LABEL ? "No category" : cat}
            </Button>
          ))}
        </div>
      </div>

      {showForm && (
        <Card>
          <CardHeader>
            <CardTitle>New credential</CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleCreate} className="space-y-4">
              <div>
                <Label>Type</Label>
                <select
                  value={form.type}
                  onChange={(e) => setForm((f) => ({ ...f, type: e.target.value }))}
                  className="mt-1 w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
                >
                  <option value="password">Password</option>
                  <option value="ssh_key">SSH key</option>
                  <option value="api_key">API key</option>
                  <option value="other">Other</option>
                </select>
              </div>
              <div>
                <Label>Name</Label>
                <Input
                  value={form.name}
                  onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                  placeholder="e.g. SAP HANA Prod"
                />
              </div>
              <div>
                <Label>Username (optional)</Label>
                <Input
                  value={form.username}
                  onChange={(e) => setForm((f) => ({ ...f, username: e.target.value }))}
                  placeholder="e.g. admin, user@example.com"
                  autoComplete="username"
                />
              </div>
              <div>
                <Label>Category (optional)</Label>
                <Input
                  value={form.category}
                  onChange={(e) => setForm((f) => ({ ...f, category: e.target.value }))}
                  placeholder="e.g. Personal, Customer XY"
                  list="category-list"
                />
                <datalist id="category-list">
                  {categories
                    .filter((c) => c !== UNGROUPED_LABEL)
                    .map((c) => (
                      <option key={c} value={c} />
                    ))}
                </datalist>
                <p className="text-xs text-muted-foreground mt-1">
                  Use categories to group and filter credentials.
                </p>
              </div>
              <div>
                <Label>Description (optional)</Label>
                <Input
                  value={form.description}
                  onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
                  placeholder="e.g. Server prod-db-01"
                />
              </div>
              <div>
                <Label>Secret / password</Label>
                <div className="flex gap-2 mt-1">
                  <Input
                    type="password"
                    value={form.secret}
                    onChange={(e) => setForm((f) => ({ ...f, secret: e.target.value }))}
                    placeholder="…"
                  />
                  <Button type="button" variant="outline" onClick={doGenerate}>
                    Generate
                  </Button>
                </div>
              </div>
              <div className="flex gap-2">
                <Button type="submit">Save</Button>
                <Button type="button" variant="outline" onClick={() => setShowForm(false)}>
                  Cancel
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      {loading ? (
        <p className="text-muted-foreground py-4">Loading…</p>
      ) : items.length === 0 ? (
        <p className="text-muted-foreground py-4">No credentials yet. Add one or use the Chat (AI) to create entries.</p>
      ) : filteredItems.length === 0 ? (
        <p className="text-muted-foreground py-4">No matches for the current search or filters.</p>
      ) : (
        <div className="rounded-lg border bg-card overflow-hidden">
          {/* Header row for column labels (optional, visible on larger screens) */}
          <div className="hidden sm:grid sm:grid-cols-12 gap-3 px-4 py-2 text-xs font-medium text-muted-foreground border-b bg-muted/30">
            <div className="sm:col-span-3">Name</div>
            <div className="sm:col-span-2">Username</div>
            <div className="sm:col-span-2">Password</div>
            <div className="sm:col-span-1">Type</div>
            <div className="sm:col-span-2">Category</div>
            <div className="sm:col-span-1">Description</div>
            <div className="sm:col-span-1 text-right">Actions</div>
          </div>
          <div className="divide-y">
            {filteredItems.map((c) => (
              <div
                key={c.id}
                className="grid grid-cols-1 sm:grid-cols-12 gap-2 sm:gap-3 px-4 py-3 hover:bg-muted/30 transition-colors items-center"
              >
                <div className="sm:col-span-3 min-w-0">
                  <p className="sm:hidden text-xs font-medium text-muted-foreground">Name</p>
                  <p className="font-medium truncate" title={c.name}>{c.name}</p>
                </div>
                <div className="sm:col-span-2 min-w-0 flex items-center gap-1">
                  <p className="sm:hidden text-xs font-medium text-muted-foreground shrink-0">Username</p>
                  {c.username?.trim() ? (
                    <>
                      <span className="text-sm text-muted-foreground truncate" title={c.username}>
                        {c.username}
                      </span>
                      <Button variant="ghost" size="icon" className="h-7 w-7 shrink-0" onClick={() => copyToClipboard(c.id, c.username!, "username")} title="Copy username">
                        <Copy className="h-4 w-4" />
                      </Button>
                      {copyFeedback?.id === c.id && copyFeedback?.kind === "username" && (
                        <span className="text-xs text-green-600 shrink-0">Copied</span>
                      )}
                    </>
                  ) : (
                    <span className="text-sm text-muted-foreground italic">—</span>
                  )}
                </div>
                <div className="sm:col-span-2 min-w-0 flex items-center gap-2">
                  <p className="sm:hidden text-xs font-medium text-muted-foreground shrink-0">Password</p>
                  <span className="font-mono text-sm min-w-0 flex-1 overflow-auto break-all bg-muted/50 px-2 py-1 rounded">
                    {holdingRevealId === c.id && secretCache[c.id] !== undefined
                      ? secretCache[c.id]
                      : "**********"}
                  </span>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="h-7 w-7 shrink-0"
                    title="Hold to show password"
                    onPointerDown={() => handleRevealPointerDown(c.id)}
                    onPointerUp={handleRevealPointerUp}
                    onPointerLeave={handleRevealPointerUp}
                  >
                    <Eye className="h-4 w-4" />
                  </Button>
                  <Button variant="ghost" size="icon" className="h-7 w-7 shrink-0" title="Copy password" onClick={() => copyPassword(c)}>
                    <Copy className="h-4 w-4" />
                  </Button>
                  {copyFeedback?.id === c.id && copyFeedback?.kind === "password" && (
                    <span className="text-xs text-green-600 shrink-0">Copied</span>
                  )}
                </div>
                <div className="sm:col-span-1">
                  <p className="sm:hidden text-xs font-medium text-muted-foreground">Type</p>
                  <span className="text-xs text-muted-foreground uppercase tracking-wide">
                    {credentialTypeLabel(c.type)}
                  </span>
                </div>
                <div className="sm:col-span-2 min-w-0">
                  <p className="sm:hidden text-xs font-medium text-muted-foreground">Category</p>
                  {c.category?.trim() ? (
                    <span className="text-xs bg-muted px-2 py-0.5 rounded">{c.category}</span>
                  ) : (
                    <span className="text-xs text-muted-foreground">—</span>
                  )}
                </div>
                <div className="sm:col-span-1 min-w-0">
                  <p className="sm:hidden text-xs font-medium text-muted-foreground">Description</p>
                  {c.description?.trim() ? (
                    <p className="text-sm text-muted-foreground truncate" title={c.description}>{c.description}</p>
                  ) : (
                    <span className="text-sm text-muted-foreground">—</span>
                  )}
                </div>
                <div className="sm:col-span-1 flex items-center justify-end">
                  <Button variant="ghost" size="icon" className="h-7 w-7 text-destructive hover:text-destructive" onClick={() => setDeleteConfirm({ id: c.id, name: c.name })} title="Delete">
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      <Dialog open={!!deleteConfirm} onOpenChange={(open) => !open && setDeleteConfirm(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Confirm delete</DialogTitle>
            <DialogDescription>
              Permanently delete “{deleteConfirm?.name}”? This cannot be undone.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteConfirm(null)} disabled={deleting}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={handleConfirmDelete} disabled={deleting}>
              {deleting ? "…" : "Delete"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
