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
import { listCredentials, createCredential, updateCredential, getCredentialSecret, deleteCredential, generatePassword, credentialTypeLabel } from "../api/client"
import type { Credential } from "../api/client"
import { useVaultSealed } from "../hooks/useVaultSealed"
import { Plus, Trash2, Eye, Search, Copy, Lock, Terminal, KeyRound, FolderKey, Pencil } from "lucide-react"

const UNGROUPED_LABEL = "— No group —"
const CREDENTIAL_TYPE_ORDER: FormType[] = ["password", "ssh_key", "api_key", "other"]

type FormType = "password" | "ssh_key" | "api_key" | "other"
const FORM_OPTIONS: Record<
  FormType,
  { nameLabel: string; namePlaceholder: string; usernameLabel: string; usernamePlaceholder: string; descriptionLabel: string; descriptionPlaceholder: string; secretLabel: string; secretPlaceholder: string; showGenerate: boolean; secretMultiline: boolean }
> = {
  password: {
    nameLabel: "Name",
    namePlaceholder: "e.g. SAP HANA Prod",
    usernameLabel: "Username (optional)",
    usernamePlaceholder: "e.g. admin, user@example.com",
    descriptionLabel: "Description (optional)",
    descriptionPlaceholder: "e.g. Server prod-db-01",
    secretLabel: "Password",
    secretPlaceholder: "…",
    showGenerate: true,
    secretMultiline: false,
  },
  ssh_key: {
    nameLabel: "Key name",
    namePlaceholder: "e.g. id_ed25519_prod",
    usernameLabel: "Key comment / ID (optional)",
    usernamePlaceholder: "e.g. user@host",
    descriptionLabel: "Notes (optional)",
    descriptionPlaceholder: "e.g. Production server",
    secretLabel: "Private key",
    secretPlaceholder: "Paste private key (PEM)…",
    showGenerate: false,
    secretMultiline: true,
  },
  api_key: {
    nameLabel: "Key name",
    namePlaceholder: "e.g. BTP API Key",
    usernameLabel: "Client ID / Username (optional)",
    usernamePlaceholder: "e.g. client_abc",
    descriptionLabel: "Service / endpoint (optional)",
    descriptionPlaceholder: "e.g. https://api.example.com",
    secretLabel: "API key",
    secretPlaceholder: "Paste API key…",
    showGenerate: false,
    secretMultiline: false,
  },
  other: {
    nameLabel: "Name",
    namePlaceholder: "e.g. My credential",
    usernameLabel: "Username (optional)",
    usernamePlaceholder: "e.g. login or identifier",
    descriptionLabel: "Description (optional)",
    descriptionPlaceholder: "e.g. Where it is used",
    secretLabel: "Secret",
    secretPlaceholder: "…",
    showGenerate: false,
    secretMultiline: false,
  },
}

// Table column labels per type (for cards)
const TABLE_LABELS: Record<FormType, { name: string; login: string; secret: string; description: string }> = {
  password: { name: "Name", login: "Username", secret: "Password", description: "Description" },
  ssh_key: { name: "Key name", login: "Key comment", secret: "Private key", description: "Notes" },
  api_key: { name: "Key name", login: "Client ID", secret: "API key", description: "Service" },
  other: { name: "Name", login: "Login / ID", secret: "Secret", description: "Description" },
}

const TYPE_ICONS: Record<FormType, typeof Lock> = {
  password: Lock,
  ssh_key: Terminal,
  api_key: KeyRound,
  other: FolderKey,
}

export function CredentialsPage() {
  const { sealed, loading: vaultLoading } = useVaultSealed()
  const navigate = useNavigate()
  const [items, setItems] = useState<Credential[]>([])
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState("")
  const [categoryFilter, setCategoryFilter] = useState<string>("")
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState({ type: "password", name: "", username: "", category: "", description: "", secret: "" })
  const [copyFeedback, setCopyFeedback] = useState<{ id: number; kind: "password" | "username" } | null>(null)
  const [holdingRevealId, setHoldingRevealId] = useState<number | null>(null)
  const [secretCache, setSecretCache] = useState<Record<number, string>>({})
  const [deleteConfirm, setDeleteConfirm] = useState<{ id: number; name: string } | null>(null)
  const [deleting, setDeleting] = useState(false)
  const [selectedTypeFilter, setSelectedTypeFilter] = useState<FormType | null>(null)
  const [editingId, setEditingId] = useState<number | null>(null)
  const [saving, setSaving] = useState(false)
  const [showSecretInForm, setShowSecretInForm] = useState(false)
  const [formCopyFeedback, setFormCopyFeedback] = useState(false)

  const load = () => {
    setLoading(true)
    listCredentials(undefined, undefined)
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
  }, [sealed, vaultLoading, navigate])

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

  // Count per type (from all items, for summary cards)
  const typeCounts = useMemo(() => {
    const counts: Record<string, number> = { password: 0, ssh_key: 0, api_key: 0, other: 0 }
    for (const c of items) {
      const t = c.type in counts ? c.type : "other"
      counts[t] += 1
    }
    return counts
  }, [items])

  if (!vaultLoading && sealed) return null

  const resetForm = () => {
    setForm({ type: "password", name: "", username: "", category: "", description: "", secret: "" })
    setShowForm(false)
    setEditingId(null)
    setShowSecretInForm(false)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const isEdit = editingId !== null
    if (!isEdit && !form.secret.trim()) return
    if (!form.name.trim()) return
    setSaving(true)
    try {
      if (isEdit) {
        await updateCredential(editingId!, {
          name: form.name.trim(),
          username: form.username.trim(),
          category: form.category.trim(),
          description: form.description.trim(),
          secret: form.secret.trim() || undefined,
        })
      } else {
        await createCredential({
          type: form.type,
          name: form.name.trim(),
          username: form.username.trim() || undefined,
          category: form.category.trim() || undefined,
          description: form.description.trim() || undefined,
          secret: form.secret,
        })
      }
      resetForm()
      load()
    } catch (err) {
      alert(err instanceof Error ? err.message : (isEdit ? "Update failed" : "Error"))
    } finally {
      setSaving(false)
    }
  }

  const openEdit = (c: Credential) => {
    setForm({
      type: c.type in TABLE_LABELS ? c.type : "password",
      name: c.name,
      username: c.username ?? "",
      category: c.category ?? "",
      description: c.description ?? "",
      secret: "",
    })
    setEditingId(c.id)
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

  const copyFormSecret = async () => {
    if (!form.secret) return
    try {
      await navigator.clipboard.writeText(form.secret)
      setFormCopyFeedback(true)
      setTimeout(() => setFormCopyFeedback(false), 1500)
    } catch {
      alert("Could not copy to clipboard.")
    }
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
        <Button
          onClick={() => {
            setEditingId(null)
            setForm({ type: "password", name: "", username: "", category: "", description: "", secret: "" })
            setShowForm(true)
          }}
        >
          <Plus className="mr-2 h-4 w-4" />
          Add new
        </Button>
      </div>

      {/* Summary cards: count per type with icon; click filters to that type */}
      {!loading && (
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          {CREDENTIAL_TYPE_ORDER.map((type) => {
            const Icon = TYPE_ICONS[type]
            const count = typeCounts[type] ?? 0
            const isActive = selectedTypeFilter === type
            return (
              <Card
                key={type}
                className={`cursor-pointer transition-colors hover:bg-muted/50 border-muted ${isActive ? "ring-2 ring-primary border-primary" : ""}`}
                onClick={() => {
                  setSelectedTypeFilter((prev) => (prev === type ? null : type))
                  if (!isActive) document.getElementById("credentials-table")?.scrollIntoView({ behavior: "smooth" })
                }}
              >
                <CardContent className="flex items-center gap-3 p-4">
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-muted">
                    <Icon className="h-5 w-5 text-muted-foreground" />
                  </div>
                  <div className="min-w-0">
                    <p className="text-sm font-medium truncate">{credentialTypeLabel(type)}</p>
                    <p className="text-2xl font-semibold tabular-nums">{count}</p>
                  </div>
                </CardContent>
              </Card>
            )
          })}
        </div>
      )}

      {/* Search + group filter */}
        <div className="rounded-lg border bg-card p-4 space-y-4">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:gap-4">
          <div className="relative flex-1 min-w-0">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground pointer-events-none" />
            <Input
              placeholder="Search by name, username, description, or group…"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9 bg-background"
            />
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-sm font-medium text-muted-foreground shrink-0">Group:</span>
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
              {cat === UNGROUPED_LABEL ? "No group" : cat}
            </Button>
          ))}
        </div>
      </div>

      {(showForm || editingId !== null) && (
        <Card>
          <CardHeader>
            <CardTitle>{editingId !== null ? "Edit credential" : "New credential"}</CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <Label>Type</Label>
                <select
                  value={form.type}
                  onChange={(e) => setForm((f) => ({ ...f, type: e.target.value }))}
                  disabled={editingId !== null}
                  className="mt-1 w-full rounded-md border border-input bg-background px-3 py-2 text-sm disabled:opacity-60 disabled:cursor-not-allowed"
                >
                  <option value="password">Password</option>
                  <option value="ssh_key">SSH key</option>
                  <option value="api_key">API key</option>
                  <option value="other">Other</option>
                </select>
                {editingId !== null && (
                  <p className="text-xs text-muted-foreground mt-1">Type cannot be changed when editing.</p>
                )}
              </div>
              {(() => {
                const opts = FORM_OPTIONS[(form.type as FormType) || "password"] ?? FORM_OPTIONS.password
                return (
                  <>
                    <div>
                      <Label>{opts.nameLabel}</Label>
                      <Input
                        value={form.name}
                        onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                        placeholder={opts.namePlaceholder}
                      />
                    </div>
                    <div>
                      <Label>{opts.usernameLabel}</Label>
                      <Input
                        value={form.username}
                        onChange={(e) => setForm((f) => ({ ...f, username: e.target.value }))}
                        placeholder={opts.usernamePlaceholder}
                        autoComplete="username"
                      />
                    </div>
                    <div>
                      <Label>Group (optional)</Label>
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
                        Use groups to organize and filter credentials.
                      </p>
                    </div>
                    <div>
                      <Label>{opts.descriptionLabel}</Label>
                      <Input
                        value={form.description}
                        onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
                        placeholder={opts.descriptionPlaceholder}
                      />
                    </div>
                    <div>
                      <Label>{opts.secretLabel}</Label>
                      <div className="flex flex-wrap items-center gap-2 mt-1">
                        {opts.secretMultiline ? (
                          <textarea
                            className="flex min-h-[120px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm font-mono placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                            value={form.secret}
                            onChange={(e) => setForm((f) => ({ ...f, secret: e.target.value }))}
                            placeholder={editingId !== null ? "Leave empty to keep current" : opts.secretPlaceholder}
                            spellCheck={false}
                          />
                        ) : (
                          <div className="flex flex-1 min-w-0 items-center gap-1 rounded-md border border-input bg-background focus-within:ring-2 focus-within:ring-ring">
                            <Input
                              type={showSecretInForm ? "text" : "password"}
                              value={form.secret}
                              onChange={(e) => setForm((f) => ({ ...f, secret: e.target.value }))}
                              placeholder={editingId !== null ? "Leave empty to keep current" : opts.secretPlaceholder}
                              className="border-0 bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0"
                            />
                            <Button
                              type="button"
                              variant="ghost"
                              size="icon"
                              className="h-8 w-8 shrink-0"
                              onClick={() => setShowSecretInForm((v) => !v)}
                              title={showSecretInForm ? "Hide" : "Show"}
                            >
                              <Eye className="h-4 w-4" />
                            </Button>
                          </div>
                        )}
                        {form.secret && (
                          <span className="flex items-center gap-1">
                            <Button type="button" variant="outline" size="icon" onClick={copyFormSecret} title="Copy to clipboard">
                              <Copy className="h-4 w-4" />
                            </Button>
                            {formCopyFeedback && <span className="text-xs text-green-600">Copied</span>}
                          </span>
                        )}
                        {opts.showGenerate && editingId === null && (
                          <Button type="button" variant="outline" onClick={doGenerate}>
                            Generate
                          </Button>
                        )}
                      </div>
                      {editingId !== null && (
                        <p className="text-xs text-muted-foreground mt-1">Leave secret empty to keep the current value.</p>
                      )}
                    </div>
                  </>
                )
              })()}
              <div className="flex gap-2">
                <Button type="submit" disabled={saving}>
                  {saving ? "…" : "Save"}
                </Button>
                <Button type="button" variant="outline" onClick={resetForm} disabled={saving}>
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
        <p className="text-muted-foreground py-4">No matches for the current search or group filter.</p>
      ) : (
        (() => {
          const list = selectedTypeFilter
            ? filteredItems.filter((c) => (c.type in TABLE_LABELS ? c.type : "other") === selectedTypeFilter)
            : [...filteredItems].sort(
                (a, b) =>
                  CREDENTIAL_TYPE_ORDER.indexOf(a.type as FormType) - CREDENTIAL_TYPE_ORDER.indexOf(b.type as FormType) ||
                  a.name.localeCompare(b.name)
              )
          return (
            <Card id="credentials-table">
              <CardContent className="p-0">
                <div className="rounded-b-lg overflow-hidden">
                  <div
                    className="hidden sm:grid gap-x-3 px-4 py-2 text-xs font-medium text-muted-foreground border-b bg-muted/30 items-center"
                    style={{ gridTemplateColumns: "2.25rem 1.5fr 2fr 3fr 1fr 2fr 2.25rem" }}
                  >
                    <div>Type</div>
                    <div>Name</div>
                    <div>Username / Key / ID</div>
                    <div>Pass / Key / Secret</div>
                    <div>Group</div>
                    <div>Description</div>
                    <div className="text-center">Actions</div>
                  </div>
                  <div className="divide-y">
                    {list.map((c) => {
                      const type: FormType = (c.type in TABLE_LABELS ? c.type : "other") as FormType
                      const labels = TABLE_LABELS[type]
                      const TypeIcon = TYPE_ICONS[type]
                      return (
                        <div
                          key={c.id}
                          className="grid grid-cols-1 gap-2 px-4 py-3 hover:bg-muted/30 transition-colors items-center sm:grid-cols-[2.25rem_1.5fr_2fr_3fr_1fr_2fr_2.25rem] sm:gap-x-3 sm:gap-y-0 sm:px-4 sm:py-2"
                        >
                          <div className="min-w-0 flex items-center justify-center sm:justify-center" title={credentialTypeLabel(type)}>
                            <p className="sm:hidden text-xs font-medium text-muted-foreground">Type</p>
                            <TypeIcon className="h-4 w-4 shrink-0 text-muted-foreground" aria-label={credentialTypeLabel(type)} />
                          </div>
                          <div className="min-w-0">
                            <p className="sm:hidden text-xs font-medium text-muted-foreground">Name</p>
                            <p className="font-medium truncate" title={c.name}>{c.name}</p>
                          </div>
                          <div className="min-w-0 flex items-center gap-1">
                            <p className="sm:hidden text-xs font-medium text-muted-foreground">Username / Key / ID</p>
                            {c.username?.trim() ? (
                              <>
                                <span className="text-sm text-muted-foreground truncate" title={c.username}>{c.username}</span>
                                <Button variant="ghost" size="icon" className="h-7 w-7 shrink-0" onClick={() => copyToClipboard(c.id, c.username!, "username")} title={`Copy ${labels.login.toLowerCase()}`}>
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
                          <div className="min-w-0 flex items-center gap-2">
                            <p className="sm:hidden text-xs font-medium text-muted-foreground">Pass / Key / Secret</p>
                            <span className="font-mono text-sm min-w-0 flex-1 overflow-auto break-all bg-muted/50 px-2 py-1 rounded">
                              {holdingRevealId === c.id && secretCache[c.id] !== undefined ? secretCache[c.id] : "**********"}
                            </span>
                            <Button variant="ghost" size="icon" className="h-7 w-7 shrink-0" title={`Hold to show ${labels.secret.toLowerCase()}`} onPointerDown={() => handleRevealPointerDown(c.id)} onPointerUp={handleRevealPointerUp} onPointerLeave={handleRevealPointerUp}>
                              <Eye className="h-4 w-4" />
                            </Button>
                            <Button variant="ghost" size="icon" className="h-7 w-7 shrink-0" title={`Copy ${labels.secret.toLowerCase()}`} onClick={() => copyPassword(c)}>
                              <Copy className="h-4 w-4" />
                            </Button>
                            {copyFeedback?.id === c.id && copyFeedback?.kind === "password" && (
                              <span className="text-xs text-green-600 shrink-0">Copied</span>
                            )}
                          </div>
                          <div className="min-w-0">
                            <p className="sm:hidden text-xs font-medium text-muted-foreground">Group</p>
                            {c.category?.trim() ? (
                              <span className="text-xs bg-muted px-2 py-0.5 rounded truncate block max-w-full" title={c.category}>{c.category}</span>
                            ) : (
                              <span className="text-xs text-muted-foreground">—</span>
                            )}
                          </div>
                          <div className="min-w-0">
                            <p className="sm:hidden text-xs font-medium text-muted-foreground">Description</p>
                            {c.description?.trim() ? (
                              <p className="text-sm text-muted-foreground truncate" title={c.description}>{c.description}</p>
                            ) : (
                              <span className="text-sm text-muted-foreground">—</span>
                            )}
                          </div>
                          <div className="flex min-w-0 items-center justify-center gap-0">
                            <Button variant="ghost" size="icon" className="h-7 w-7 shrink-0" onClick={() => openEdit(c)} title="Edit">
                              <Pencil className="h-4 w-4" />
                            </Button>
                            <Button variant="ghost" size="icon" className="h-7 w-7 shrink-0 text-destructive hover:text-destructive" onClick={() => setDeleteConfirm({ id: c.id, name: c.name })} title="Delete">
                              <Trash2 className="h-4 w-4" />
                            </Button>
                          </div>
                        </div>
                      )
                    })}
                  </div>
                </div>
              </CardContent>
            </Card>
          )
        })()
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
