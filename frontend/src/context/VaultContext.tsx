import { createContext, useContext, useState, useEffect, useCallback } from "react"
import { vaultStatus } from "../api/client"

type VaultContextType = {
  sealed: boolean
  loading: boolean
  backendUnreachable: boolean
  refresh: () => Promise<boolean>
}

const VaultContext = createContext<VaultContextType | null>(null)

export function VaultProvider({ children }: { children: React.ReactNode }) {
  const [sealed, setSealed] = useState(true)
  const [loading, setLoading] = useState(true)
  const [backendUnreachable, setBackendUnreachable] = useState(false)

  useEffect(() => {
    vaultStatus()
      .then((d) => {
        setSealed(d.sealed)
        setBackendUnreachable(false)
      })
      .catch(() => {
        setSealed(true)
        setBackendUnreachable(true)
      })
      .finally(() => setLoading(false))
  }, [])

  const refresh = useCallback(() => {
    setLoading(true)
    setBackendUnreachable(false)
    return vaultStatus()
      .then((d) => {
        setSealed(d.sealed)
        setBackendUnreachable(false)
        return d.sealed
      })
      .catch(() => {
        setBackendUnreachable(true)
        throw new Error("Backend nicht erreichbar")
      })
      .finally(() => setLoading(false))
  }, [])

  return (
    <VaultContext.Provider value={{ sealed, loading, backendUnreachable, refresh }}>
      {children}
    </VaultContext.Provider>
  )
}

export function useVaultSealed(): VaultContextType {
  const ctx = useContext(VaultContext)
  if (!ctx) throw new Error("useVaultSealed must be used within VaultProvider")
  return ctx
}
