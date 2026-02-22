# Preview-Screenshots für die README

Die Vorschaubilder im README sollen das echte Aussehen der App zeigen. Dafür eignen sich **Screenshots** der laufenden App.

## So erstellst du die Bilder

1. **App starten** (lokal oder Docker), z. B.:
   ```bash
   ./scripts/start-docker.sh
   ```
   oder `./scripts/start-local.sh backend` + `./scripts/start-local.sh frontend`.

2. **Zwei Screenshots** im Browser erstellen (am besten gleiches Fenster, z. B. 1200×800 px oder vergleichbar):

   | Datei | Seite |
   |-------|--------|
   | `assets/preview-unseal.png` | **Unseal:** Vault geschlossen, Seite „Open vault (Unseal)“ mit Master-Key-Feld. (Vor dem ersten Öffnen oder nach „Seal“.) |
   | `assets/preview-credentials.png` | **Credentials:** Vault offen, Navigationspunkt „Credentials“ – Übersicht mit Summary-Cards und Credential-Tabelle (mit oder ohne Einträge). |

3. **Speichern:** Die Screenshots unter den genannten Dateinamen im Ordner **`assets/`** (Projektroot) ablegen. Vorhandene Dateien mit gleichem Namen werden ersetzt.

4. **Optional:** Bilder verkleinern, damit die README auf GitHub schnell lädt (z. B. Breite 800–1000 px). Unter macOS z. B.:
   ```bash
   sips -Z 900 assets/preview-*.png
   ```

## Theme

Du kannst die App im gewünschten Theme (Hell/Dunkel) öffnen – die README-Vorschau entspricht dann diesem Look. Standard ist Systemeinstellung („prefers-color-scheme“).
