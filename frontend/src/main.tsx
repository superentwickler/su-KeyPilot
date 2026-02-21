import React from "react"
import ReactDOM from "react-dom/client"
import { BrowserRouter } from "react-router-dom"
import { VaultProvider } from "./context/VaultContext"
import { ThemeProvider } from "./context/ThemeContext"
import App from "./App"
import "./index.css"

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <BrowserRouter>
      <ThemeProvider>
        <VaultProvider>
          <App />
        </VaultProvider>
      </ThemeProvider>
    </BrowserRouter>
  </React.StrictMode>
)
