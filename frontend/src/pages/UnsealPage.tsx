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
  const [fileInputKey, setFileInputKey] = useState(0)
  const [dataDir, setDataDir] = useState<string | null>(null)
  const [hintDismissed, setHintDismissed] = useState(() => !!localStorage.getItem(HINT_DISMISSED_KEY))
  const navigate = useNavigate()
  const { refresh } = useVaultSealed()

  useEffect(() => {
    getAppInfo().then((info) => setDataDir(info.data_dir))
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
    setError("")
    setRestoreMessage("")
    try {
      const res = await restoreBackup(restoreFile)
      setRestoreMessage(res.message)
      setRestoreFile(null)
      setFileInputKey((k) => k + 1)
      await refresh()
    } catch (err) {
      setError(err instanceof Error ? err.message : "Restore failed")
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
      {dataDir && !hintDismissed && (
        <div className="rounded-lg border bg-muted/50 px-4 py-3 text-sm text-muted-foreground flex items-start justify-between gap-2">
          <span>
            <strong className="text-foreground">Data storage location:</strong> {dataDir}
            <br />
            Configurable: Docker/Web server <code className="text-xs">KEYPILOT_DATA_DIR</code> in .env in the project root (e.g. iCloud/OneDrive folder); local: <code className="text-xs">backend/data</code> folder. See README.
          </span>
          <Button variant="ghost" size="sm" onClick={dismissHint} className="shrink-0">
            Dismiss
          </Button>
        </div>
      )}
      <Card>
        <CardHeader>
          <CardTitle>Open vault (Unseal)</CardTitle>
          <p className="text-sm text-muted-foreground">
            <strong>First time?</strong> There is no default key – choose a secure password now. That becomes your master key. Remember it; without it you cannot decrypt stored secrets after a restart.
          </p>
          <p className="text-sm text-muted-foreground mt-2">
            The key is never stored on disk, only kept in memory.
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
          {restoreMessage && (
            <p className="text-sm text-muted-foreground bg-muted p-2 rounded">
              {restoreMessage}
            </p>
          )}
        </CardContent>
      </Card>

      <Card className="border-muted">
        <CardHeader>
          <CardTitle className="text-sm font-medium">Data storage location</CardTitle>
          <p className="text-sm text-muted-foreground">
            Where the database (passwords, vault) is stored. Configurable via configuration – not in the app.
          </p>
        </CardHeader>
        <CardContent className="space-y-2">
          {dataDir ? (
            <p className="text-sm font-mono bg-muted px-2 py-1.5 rounded break-all">{dataDir}</p>
          ) : (
            <p className="text-sm text-muted-foreground">Not available (e.g. with PostgreSQL).</p>
          )}
          <p className="text-xs text-muted-foreground">
            <strong>Docker / Web server:</strong> <code>KEYPILOT_DATA_DIR</code> in .env in the project root (e.g. iCloud/OneDrive folder).
            <br />
            <strong>Local:</strong> <code>backend/data</code> folder in the project. See README.
          </p>
        </CardContent>
      </Card>
    </div>
  )
}
