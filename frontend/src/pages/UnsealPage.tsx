import { useState } from "react"
import { useNavigate } from "react-router-dom"
import { Button } from "../components/ui/button"
import { Input } from "../components/ui/input"
import { Label } from "../components/ui/label"
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card"
import { unseal, resetVault, restoreBackup } from "../api/client"
import { useVaultSealed } from "../hooks/useVaultSealed"

export function UnsealPage() {
  const [masterKey, setMasterKey] = useState("")
  const [error, setError] = useState("")
  const [loading, setLoading] = useState(false)
  const [resetConfirm, setResetConfirm] = useState("")
  const [resetting, setResetting] = useState(false)
  const [restoreFile, setRestoreFile] = useState<File | null>(null)
  const [restoring, setRestoring] = useState(false)
  const [restoreMessage, setRestoreMessage] = useState("")
  const [fileInputKey, setFileInputKey] = useState(0)
  const navigate = useNavigate()
  const { refresh } = useVaultSealed()

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

  const handleReset = async () => {
    if (resetConfirm !== "RESET") return
    setResetting(true)
    setError("")
    try {
      await resetVault()
      setResetConfirm("")
      await refresh()
    } catch (err) {
      setError(err instanceof Error ? err.message : "Reset failed")
    } finally {
      setResetting(false)
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

  return (
    <div className="max-w-md mx-auto space-y-6">
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

      <Card className="border-destructive/50">
        <CardHeader>
          <CardTitle className="text-destructive text-base">Reset vault</CardTitle>
          <p className="text-sm text-muted-foreground">
            Deletes all stored credentials and the salt. On next open you can set a <strong>new</strong> master key (e.g. if you forgot the old one). This cannot be undone.
          </p>
        </CardHeader>
        <CardContent className="space-y-3">
          <p className="text-sm">Type <strong>RESET</strong> to confirm:</p>
          <Input
            value={resetConfirm}
            onChange={(e) => setResetConfirm(e.target.value)}
            placeholder="RESET"
            className="font-mono max-w-[8rem]"
            autoComplete="off"
          />
          {error && <p className="text-sm text-destructive">{error}</p>}
          <Button variant="destructive" onClick={handleReset} disabled={resetConfirm !== "RESET" || resetting}>
            {resetting ? "…" : "Reset vault"}
          </Button>
        </CardContent>
      </Card>
    </div>
  )
}
