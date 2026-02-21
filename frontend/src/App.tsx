import { Routes, Route } from "react-router-dom"
import { Layout } from "./components/Layout"
import { UnsealPage } from "./pages/UnsealPage"
import { CredentialsPage } from "./pages/CredentialsPage"
import { ChatPage } from "./pages/ChatPage"

export default function App() {
  return (
    <Layout>
      <Routes>
        <Route path="/" element={<CredentialsPage />} />
        <Route path="/unseal" element={<UnsealPage />} />
        <Route path="/chat" element={<ChatPage />} />
      </Routes>
    </Layout>
  )
}
