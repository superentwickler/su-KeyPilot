# KeyPilot – Secure backup

## In short: back up the DB file only

- **Backup = the database file** (`backend/data/keypilot.db` or your KEYPILOT_DATA_DIR).
- It contains only: **encrypted** credentials (ciphertext) and the **salt**. The **master key** is never stored there.

**Without the master key**, the DB (or a copy) is useless – everything stays encrypted.  
**With the master key**, after a restore (replace DB file, start backend, open vault) you can use everything again.

Optional: Encrypt the backup file with a password (e.g. OpenSSL) so that anyone with file access cannot read it as a DB.

---

## Two keys

| Key | Purpose |
|-----|---------|
| **Master key** | Opens the vault in daily use; **not** stored in the backup. You must remember it. |
| **Backup password** | Protects the **backup file** (e.g. encrypted export). Only someone who knows this password can decrypt and use the file. |

Recommendation: Keep the master key and backup password **separate** and secure (e.g. master key in memory/password manager, backup password elsewhere or in a safe).

---

## Option A: Manual backup (no app feature)

### 1. Create backup

```bash
cd backend
# Optionally seal vault first (clear key from memory)
cp data/keypilot.db backup/keypilot_$(date +%Y%m%d).db
# Encrypt backup (e.g. with OpenSSL)
openssl enc -aes-256-cbc -salt -pbkdf2 -in backup/keypilot_*.db -out backup/keypilot_$(date +%Y%m%d).db.enc
# Remove unencrypted copy
rm backup/keypilot_*.db
```

### 2. Store backup

- Locked media (USB, external drive) or encrypted cloud storage.
- Do **not** store the backup password on the same medium; e.g. note in a safe or in a second password manager.

### 3. Restore

- Decrypt the `.enc` file with OpenSSL (enter password).
- Place the decrypted DB at `backend/data/keypilot.db` (back up or rename the old DB first).
- Restart the backend and open the vault with the **same master key** as before the backup.

---

## Option B: Backup via the app

- **Download:** In the app, use “Backup” to download the current DB (e.g. `keypilot_backup_YYYYMMDD.db`). Optionally encrypt it yourself (OpenSSL) before storing.
- **Restore:** On the Unseal page, use “Restore backup”, choose a `.db` file → it replaces the current DB. Restart the backend and open the vault with the **master key** of the restored DB.

---

## Recommendations

1. **Regularity:** e.g. weekly or after major changes.
2. **Storage:** At least one backup in a **different location** (not only on the same machine).
3. **Test:** Occasionally test restore on a test instance (backup password + master key).
4. **Backup password:** Strong and stored separately from the master key; if lost, the backup cannot be used.
