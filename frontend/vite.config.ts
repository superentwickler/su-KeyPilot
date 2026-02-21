import path from "path"
import { fileURLToPath } from "url"
import react from "@vitejs/plugin-react"
import { defineConfig, loadEnv } from "vite"

const __dirname = path.dirname(fileURLToPath(import.meta.url))

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, __dirname, "")
  const port = parseInt(env.FRONTEND_PORT || env.PORT || "5173", 10)
  return {
    plugins: [react()],
    resolve: { alias: { "@": path.resolve(__dirname, "./src") } },
    server: {
      port,
      proxy: {
        "/vault": "http://localhost:8000",
        "/credentials": "http://localhost:8000",
        "/chat": "http://localhost:8000",
        "/utils": "http://localhost:8000",
        "/health": "http://localhost:8000",
      },
    },
  }
})
