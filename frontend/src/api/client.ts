const BASE = "" // Vite proxy zu localhost:8000

export async function vaultStatus() {
  const r = await fetch(`${BASE}/vault/status`)
  if (!r.ok) throw new Error("Vault status failed")
  return r.json() as Promise<{ sealed: boolean }>
}

export async function unseal(masterKey: string) {
  const r = await fetch(`${BASE}/vault/unseal`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ master_key: masterKey }),
  })
  if (!r.ok) {
    const e = await r.json().catch(() => ({}))
    throw new Error(e.detail || "Unseal failed")
  }
  return r.json()
}

export async function seal() {
  const r = await fetch(`${BASE}/vault/seal`, { method: "POST" })
  if (!r.ok) throw new Error("Seal failed")
  return r.json()
}

export async function resetVault() {
  const r = await fetch(`${BASE}/vault/reset`, { method: "POST" })
  if (!r.ok) throw new Error("Reset failed")
  return r.json()
}

export type Credential = {
  id: number
  type: string
  name: string
  username?: string
  category: string
  description: string
  created_at: string
  updated_at: string
}

function apiErrorDetail(body: unknown, fallback: string): string {
  if (body && typeof body === "object" && "detail" in body) {
    const d = (body as { detail: unknown }).detail
    if (typeof d === "string") return d
    if (Array.isArray(d) && d[0] && typeof d[0] === "object" && "msg" in d[0]) return String((d[0] as { msg: unknown }).msg)
  }
  return fallback
}

export async function listCredentials(type?: string, category?: string): Promise<Credential[]> {
  const params = new URLSearchParams()
  if (type) params.set("type", type)
  if (category) params.set("category", category)
  const r = await fetch(`${BASE}/credentials?${params}`)
  if (!r.ok) {
    const e = await r.json().catch(() => ({}))
    throw new Error(apiErrorDetail(e, "List credentials failed"))
  }
  return r.json()
}

export async function createCredential(data: {
  type: string
  name: string
  username?: string
  category?: string
  description?: string
  secret: string
}) {
  const r = await fetch(`${BASE}/credentials`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  })
  if (!r.ok) {
    const e = await r.json().catch(() => ({}))
    throw new Error(apiErrorDetail(e, "Create failed"))
  }
  return r.json()
}

export async function getCredentialSecret(id: number): Promise<string> {
  const r = await fetch(`${BASE}/credentials/${id}/secret`)
  if (!r.ok) {
    const e = await r.json().catch(() => ({}))
    throw new Error(apiErrorDetail(e, "Get secret failed"))
  }
  const d = await r.json()
  return d.secret
}

export async function deleteCredential(id: number) {
  const r = await fetch(`${BASE}/credentials/${id}`, { method: "DELETE" })
  if (!r.ok) {
    const e = await r.json().catch(() => ({}))
    throw new Error(apiErrorDetail(e, "Delete failed"))
  }
}

export async function generatePassword(): Promise<string> {
  const r = await fetch(`${BASE}/utils/generate-password`)
  if (!r.ok) throw new Error("Generate password failed")
  const d = await r.json()
  return d.password
}

/** Speicherort der DB (für Hinweis/Anzeige in der App). */
export async function getAppInfo(): Promise<{ data_dir: string | null; database: string }> {
  const r = await fetch(`${BASE}/utils/info`)
  if (!r.ok) return { data_dir: null, database: "other" }
  return r.json()
}

/** Backup-Datei (DB) vom Server laden und als Download anbieten. */
export async function downloadBackup(): Promise<void> {
  const r = await fetch(`${BASE}/utils/backup`)
  if (!r.ok) {
    const e = await r.json().catch(() => ({}))
    throw new Error(e.detail || "Backup not available")
  }
  const blob = await r.blob()
  const name =
    r.headers.get("Content-Disposition")?.match(/filename="?([^";]+)"?/)?.[1] ??
    `keypilot_backup_${new Date().toISOString().slice(0, 10)}.db`
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  a.href = url
  a.download = name
  a.click()
  URL.revokeObjectURL(url)
}

/** Hochgeladene Backup-Datei (.db) wiederherstellen. Danach Backend neu starten. */
export async function restoreBackup(file: File): Promise<{ message: string }> {
  const form = new FormData()
  form.append("file", file)
  const r = await fetch(`${BASE}/utils/restore`, {
    method: "POST",
    body: form,
  })
  if (!r.ok) {
    const e = await r.json().catch(() => ({}))
    const detail = typeof e.detail === "string" ? e.detail : e.detail?.[0]?.msg ?? "Restore failed"
    throw new Error(detail)
  }
  return r.json()
}

/** Human-readable type label */
export function credentialTypeLabel(type: string): string {
  switch (type) {
    case "password": return "Password"
    case "ssh_key": return "SSH key"
    case "api_key": return "API key"
    case "other": return "Other"
    default: return type
  }
}

export async function chat(message: string): Promise<{ reply: string; action_performed?: string }> {
  const r = await fetch(`${BASE}/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message }),
  })
  if (!r.ok) {
    const e = await r.json().catch(() => ({}))
    const detail = typeof e.detail === "string" ? e.detail : "Chat failed"
    throw new Error(detail)
  }
  return r.json()
}
