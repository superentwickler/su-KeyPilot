import { useState, useEffect } from "react"
import { useNavigate } from "react-router-dom"
import { Button } from "../components/ui/button"
import { Input } from "../components/ui/input"
import { Label } from "../components/ui/label"
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card"
import { unseal, restoreBackup, getAppInfo } from "../api/client"
import { useVaultSealed } from "../hooks/useVaultSealed"

const HINT_DISMISSED_KEY = "keypilot-datadir-hint-dismissed"

export function UnsealPage() {
  const [masterKey, setMasterKey] = useState("")
  const [error, setError] = useState("")
  const [loading, setLoading] = useState(false)
  const [restoreFile, setRestoreFile] = useState<File | null>(null)
  const [restoring, setRestoring] = useState(false)
  const [restoreMessage, setRestoreMessage] = useState("")
  const [restoreError, setRestoreError] = useState("")
  const [fileInputKey, setFileInputKey] = useState(0)
  const [appInfo, setAppInfo] = useState<{
    data_dir: string | null
    db_path: string | null
    database: string
  }>({ data_dir: null, db_path: null, database: "other" })
  const [hintDismissed, setHintDismissed] = useState(() => !!localStorage.getItem(HINT_DISMISSED_KEY))
  const navigate = useNavigate()
  const { refresh } = useVaultSealed()

  useEffect(() => {
    getAppInfo().then(setAppInfo)
  }, [])

  const handleUnseal = async (e: React.FormEvent) => {
    e.preventDefault()
    setError("")
    setLoading(true)
    try {
      await unseal(masterKey)
      setMasterKey("")
      await refresh()
      navigate("/", { replace: true })
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unseal failed")
    } finally {
      setLoading(false)
    }
  }

  const handleRestore = async () => {
    if (!restoreFile) return
    setRestoring(true)
    setRestoreError("")
    setRestoreMessage("")
    try {
      const res = await restoreBackup(restoreFile)
      setRestoreMessage(res.message)
      setRestoreFile(null)
      setFileInputKey((k) => k + 1)
      await refresh()
    } catch (err) {
      setRestoreError(err instanceof Error ? err.message : "Restore failed")
    } finally {
      setRestoring(false)
    }
  }

  const dismissHint = () => {
    localStorage.setItem(HINT_DISMISSED_KEY, "1")
    setHintDismissed(true)
  }

  return (
    <div className="max-w-md mx-auto space-y-6">
      {appInfo.db_path && !hintDismissed && (
        <div className="rounded-lg border bg-muted/50 px-4 py-3 text-sm text-muted-foreground flex items-start justify-between gap-2">
          <span>
            <strong className="text-foreground">Database in use:</strong> <code className="text-xs break-all">{appInfo.db_path}</code>
            <br />
            Set via <code className="text-xs">KEYPILOT_DATA_DIR</code> (Docker: project root .env; local: <code className="text-xs">backend/.env</code>, paths inside project only). See README.
          </span>
          <Button variant="ghost" size="sm" onClick={dismissHint} className="shrink-0">
            Dismiss
          </Button>
        </div>
      )}
      <Card>
        <CardHeader>
          <CardTitle>Open vault (Unseal)</CardTitle>
          {appInfo.db_path && (
            <p className="text-xs text-muted-foreground font-mono bg-muted/50 px-2 py-1.5 rounded break-all mb-2">
              Database: {appInfo.db_path}
            </p>
          )}
          <p className="text-sm text-muted-foreground">
            <strong>First time?</strong> Choose a secure password – that becomes your master key. Remember it; without it you cannot decrypt stored secrets.
          </p>
          <p className="text-sm text-muted-foreground mt-2">
            <strong>Already use this vault?</strong> Enter the master key you set when you first opened it. The key is never stored on disk.
          </p>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleUnseal} className="space-y-4">
            <div>
              <Label htmlFor="master">Master key</Label>
              <Input
                id="master"
                type="password"
                value={masterKey}
                onChange={(e) => setMasterKey(e.target.value)}
                placeholder="…"
                autoComplete="off"
                className="mt-1"
              />
            </div>
            {error && <p className="text-sm text-destructive">{error}</p>}
            <Button type="submit" disabled={!masterKey.trim() || loading}>
              {loading ? "…" : "Open vault"}
            </Button>
          </form>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Restore backup</CardTitle>
          <p className="text-sm text-muted-foreground">
            Choose a previously saved <strong>.db</strong> file. It will replace the current database. Then restart the backend and open the vault with the master key of the restored DB.
          </p>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="flex flex-wrap items-center gap-2">
            <Input
              key={fileInputKey}
              type="file"
              accept=".db"
              onChange={(e) => setRestoreFile(e.target.files?.[0] ?? null)}
              className="max-w-xs"
            />
            <Button
              variant="secondary"
              onClick={handleRestore}
              disabled={!restoreFile || restoring}
            >
              {restoring ? "…" : "Restore"}
            </Button>
          </div>
          {restoreError && (
            <p className="text-sm text-destructive bg-destructive/10 p-2 rounded">
              {restoreError}
            </p>
          )}
          {restoreMessage && (
            <p className="text-sm text-muted-foreground bg-muted p-2 rounded">
              {restoreMessage}
            </p>
          )}
          <p className="text-xs text-muted-foreground">
            If restore fails (e.g. file in use): stop the backend, run <code className="bg-muted px-1 rounded">./scripts/restore.sh &lt;yourfile.db&gt;</code>, then start the backend again.
          </p>
        </CardContent>
      </Card>
    </div>
  )
}
