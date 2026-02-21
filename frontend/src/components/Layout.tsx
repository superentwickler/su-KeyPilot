import { useEffect, useState } from "react"
import { Link, useNavigate, useLocation } from "react-router-dom"
import { Key, List, MessageSquare, Lock, Download, Moon, Sun } from "lucide-react"
import { Button } from "./ui/button"
import { useVaultSealed } from "../hooks/useVaultSealed"
import { useTheme } from "../context/ThemeContext"
import { seal as sealApi, downloadBackup } from "../api/client"

export function Layout({ children }: { children: React.ReactNode }) {
  const { sealed, loading, backendUnreachable, refresh } = useVaultSealed()
  const { theme, toggleTheme } = useTheme()
  const navigate = useNavigate()
  const location = useLocation()
  const isUnsealPage = location.pathname === "/unseal"
  const [sealing, setSealing] = useState(false)
  const [backingUp, setBackingUp] = useState(false)

  const handleSeal = async () => {
    setSealing(true)
    try {
      await sealApi()
      await refresh()
      navigate("/unseal", { replace: true })
    } finally {
      setSealing(false)
    }
  }

  const handleBackup = async () => {
    setBackingUp(true)
    try {
      await downloadBackup()
    } catch (e) {
      alert(e instanceof Error ? e.message : "Backup failed")
    } finally {
      setBackingUp(false)
    }
  }

  // Bei versiegeltem Vault: Aufrufe von / oder /chat auf /unseal umleiten (Menüs nicht erreichbar)
  useEffect(() => {
    if (!loading && sealed && !isUnsealPage) {
      navigate("/unseal", { replace: true })
    }
  }, [loading, sealed, isUnsealPage, navigate])

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <span className="text-muted-foreground">Loading…</span>
      </div>
    )
  }

  if (backendUnreachable) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-muted/30 p-6">
        <div className="text-center space-y-4 max-w-md">
          <p className="font-medium">Backend unreachable</p>
          <p className="text-sm text-muted-foreground">
            The dev server cannot connect to <code className="bg-muted px-1 rounded">localhost:8000</code>.
            Start the backend in a separate terminal, or run the full app with Docker.
          </p>
          <div className="text-left text-sm space-y-2">
            <p className="text-muted-foreground font-medium">Option 1 – Backend locally:</p>
            <pre className="bg-muted p-4 rounded-md overflow-x-auto">
              cd backend && uvicorn app.main:app --reload --port 8000
            </pre>
            <p className="text-muted-foreground font-medium mt-2">Option 2 – Full app in Docker:</p>
            <pre className="bg-muted p-4 rounded-md overflow-x-auto">
              ./scripts/start-docker.sh
            </pre>
          </div>
          <Button onClick={refresh}>Retry</Button>
        </div>
      </div>
    )
  }

  if (sealed && !isUnsealPage) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-muted/30">
        <div className="text-center space-y-4">
          <p className="text-muted-foreground">Vault is sealed. Open it first.</p>
          <Button onClick={() => navigate("/unseal")}>Open vault (Unseal)</Button>
        </div>
      </div>
    )
  }

  // Vault versiegelt, aber schon auf Unseal-Seite: nur Unseal-Formular, keine anderen Menüs
  if (sealed && isUnsealPage) {
    return (
      <div className="min-h-screen flex flex-col">
        <header className="border-b bg-card px-4 py-3 flex items-center justify-between">
          <span>
            <span className="font-semibold text-lg">KeyPilot</span>
            <span className="ml-2 text-sm text-muted-foreground">– Vault sealed</span>
          </span>
          <Button variant="ghost" size="sm" onClick={toggleTheme} title={theme === "dark" ? "Light mode" : "Dark mode"}>
            {theme === "dark" ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
          </Button>
        </header>
        <main className="flex-1 p-6">{children}</main>
        <footer className="border-t py-1.5 px-4 text-center text-xs text-muted-foreground">
          superentwickler · MIT License © 2026
        </footer>
      </div>
    )
  }

  // Vault offen: volle Navigation (Credentials, Chat, Vault)
  return (
    <div className="min-h-screen flex flex-col">
      <header className="border-b bg-card px-4 py-3 flex items-center gap-4">
        <Link to="/" className="font-semibold text-lg">
          KeyPilot
        </Link>
        <nav className="flex gap-2 flex-1">
          <Link to="/">
            <Button variant="ghost" size="sm">
              <List className="mr-1 h-4 w-4" />
              Credentials
            </Button>
          </Link>
          <Link to="/chat">
            <Button variant="ghost" size="sm">
              <MessageSquare className="mr-1 h-4 w-4" />
              Chat
            </Button>
          </Link>
          <Link to="/unseal">
            <Button variant="outline" size="sm">
              <Key className="mr-1 h-4 w-4" />
              Vault
            </Button>
          </Link>
          <Button variant="ghost" size="sm" onClick={handleBackup} disabled={backingUp} title="Download backup (DB)">
            <Download className="mr-1 h-4 w-4" />
            {backingUp ? "…" : "Backup"}
          </Button>
          <Button variant="ghost" size="sm" onClick={handleSeal} disabled={sealing} title="Seal vault">
            <Lock className="mr-1 h-4 w-4" />
            {sealing ? "…" : "Seal vault"}
          </Button>
          <Button variant="ghost" size="sm" onClick={toggleTheme} title={theme === "dark" ? "Light mode" : "Dark mode"}>
            {theme === "dark" ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
          </Button>
        </nav>
      </header>
      <main className="flex-1 p-6">{children}</main>
      <footer className="border-t py-1.5 px-4 text-center text-xs text-muted-foreground">
        superentwickler · MIT License © 2026
      </footer>
    </div>
  )
}
