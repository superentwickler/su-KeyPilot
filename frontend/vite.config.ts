import path from "path"
import { fileURLToPath } from "url"
import react from "@vitejs/plugin-react"
import { defineConfig } from "vite"

const __dirname = path.dirname(fileURLToPath(import.meta.url))

export default defineConfig({
  plugins: [react()],
  resolve: { alias: { "@": path.resolve(__dirname, "./src") } },
  server: {
    port: 5173,
    proxy: {
      "/vault": "http://localhost:8000",
      "/credentials": "http://localhost:8000",
      "/chat": "http://localhost:8000",
      "/utils": "http://localhost:8000",
      "/health": "http://localhost:8000",
    },
  },
})
