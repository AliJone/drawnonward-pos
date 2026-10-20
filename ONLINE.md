# Working from more than one place: the online database and sync

drawnonward POS can run on several PCs (the shop till, a PC at home, a laptop) that all share one set of data through an **online database**. Each install runs in one of two modes, set in its `.env` file:

- **Online mode** (`sync.mode='online'`): the install works directly on the online database. Every sale, item and report is read from and written to it immediately. Several online-mode installs can be used at the same time.
- **Offline mode** (`sync.mode='offline'`): the install works on its own local database, which is fast and keeps working when the internet is poor, and moves the data to and from the online database as whole snapshots. **Only one offline site can hold the data at a time**: logging in takes a lock stored in the online database, pulls the latest data, and logging out pushes the data back and releases the lock. While a site holds the lock, logins elsewhere are refused with a message that names it.

Both modes log in through the online database, so an install that cannot reach it cannot log in, with one exception: an offline-mode site that already holds the lock may keep working and log in again while the internet is down.

Everyone is logged out automatically after 30 minutes without activity (`sync.idleMinutes`). In offline mode that logout also syncs and releases the lock, so a till left logged in overnight does not block the home PC the next morning.

Support: info@drawnonward.org · +923182232414

---

## 1. Create the online database

The online database is a MariaDB or MySQL server reachable from every site. It only holds the lock, the login credentials and the latest snapshot; day-to-day work happens on each PC's local database. Two ways to get one:

### Option A: a managed MariaDB service (simplest)

A hosted database gives you a host name, a port, a user and a password, and nothing to maintain. Two free options:

- **MariaDB Cloud (SkySQL)**, https://skysql.com: the Free Developer Tier is a perpetually free serverless MariaDB (0.5 vCPU and 2 GB baseline, scales to zero when idle, so the first query after a quiet period takes a moment). Same engine as the POS's local database, which makes it the recommended choice.
- **Aiven for MySQL**, https://aiven.io: free plan with 1 CPU, 1 GB RAM and 1 GB disk. This is MySQL 8, not MariaDB; the first sync copies the MariaDB table definitions to the online database, and that step has not been verified against MySQL 8.

Steps for MariaDB Cloud:

1. Sign up, choose **Serverless**, the Free Developer Tier, the MariaDB engine and the region closest to the shop, and launch the service.
2. **Secure access / IP allowlist**: the service refuses every connection until an address is allowed. Shop and home internet connections usually have changing addresses, so allow `0.0.0.0/0`; the password and TLS protect the database.
3. **Connect to service**: note the host name, port (not 3306), user name and password. Change the default password right away with the `SET PASSWORD` statement the page shows.
4. Create the database once, from the portal's SQL editor or any MySQL client: `CREATE DATABASE drawnonward;`

Every install then needs these `.env` lines (see section 2), with the values from the portal:

```ini
database.cloud.hostname='<host name from the portal>'
database.cloud.port=<port from the portal>
database.cloud.database='drawnonward'
database.cloud.username='<user from the portal>'
database.cloud.password='<password>'
database.cloud.encrypt=true
```

`encrypt=true` encrypts the connection and verifies the server's certificate. MariaDB Cloud's certificate is issued by a public authority, so Docker installs need nothing more. Two cases need `database.cloud.sslCa`: a provider with its own certificate authority (Aiven) and XAMPP installs, which have no system certificate store. For Aiven, save the CA file downloaded from its console as `cloud-ca.pem` in the project folder, set `database.cloud.sslCa='/app/cloud-ca.pem'`, and for Docker installs add the line `- ./cloud-ca.pem:/app/cloud-ca.pem:ro` under `volumes:` of the `drawnonward` service in `docker-compose.yml`. For XAMPP, set `database.cloud.sslCa='C:/xampp/apache/bin/curl-ca-bundle.crt'` (public authorities) or the provider's CA file. A wrong CA file makes every login fail with *The online database cannot be reached*.

### Option B: a free Oracle Cloud virtual machine (no monthly cost, more work)

Oracle's **Always Free** tier includes an Arm virtual machine (VM.Standard.A1.Flex, up to 4 cores and 24 GB) that can run MariaDB in Docker indefinitely at no charge. Note that Oracle's *MySQL HeatWave Database Service* is **not** part of Always Free; it only comes with 30-day trial credits and is billed afterwards, so use the virtual machine route.

1. Sign up at https://cloud.oracle.com, choose a home region close to the shop, and complete the identity check (a credit card is required but not charged for Always Free resources).
2. **Compute → Instances → Create instance**. Name it `drawnonward-db`, image **Ubuntu 22.04 (aarch64)**, shape **VM.Standard.A1.Flex** with 2 OCPUs and 12 GB (within the free limits), and download the SSH key pair it offers. Leave the public IP assigned.
3. Connect from your PC: `ssh -i <downloaded key> ubuntu@<public IP>` (PowerShell has `ssh` built in).
4. Install Docker on the VM:

   ```bash
   curl -fsSL https://get.docker.com | sudo sh
   sudo usermod -aG docker ubuntu && newgrp docker
   ```

5. Install Tailscale on the VM and on every PC that will use the POS (https://tailscale.com/download, free for up to 100 devices). Tailscale gives each device a private address like `100.101.102.103` and encrypts all traffic between them, so the database port is never exposed to the internet and no TLS certificates are needed. On the VM: `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up`, then follow the link to sign in. Note the VM's Tailscale address with `tailscale ip -4`.
6. Start MariaDB, bound to the Tailscale address only (replace the address and choose strong passwords):

   ```bash
   docker run -d --name drawnonward-db --restart always \
     -p 100.101.102.103:3306:3306 \
     -v drawnonward-db:/var/lib/mysql \
     -e MYSQL_ROOT_PASSWORD='choose-a-root-password' \
     -e MYSQL_DATABASE=drawnonward \
     -e MYSQL_USER=admin \
     -e MYSQL_PASSWORD='choose-the-pos-password' \
     mariadb:10.5
   ```

   Because the port is bound to the Tailscale address, nothing needs to be opened in Oracle's network security list. Do not publish the port on the public IP.
7. From a PC on the same Tailscale network, test with any MySQL client, or simply continue with the install configuration below: the Sync tab has a **Test connection** button.

Back up the VM's database too: the POS backup script (`tools\backup`) runs on each PC and includes whatever that PC holds; for the online database itself, schedule `docker exec drawnonward-db sh -c 'mysqldump -uadmin -p"$MYSQL_PASSWORD" drawnonward' > backup.sql` on the VM or let an offline site's backups cover it.

---

## 2. Configure each install

Every install keeps working as before until `sync.mode` is set. The settings live in `.env`; copy the block from `.env.example` if it is missing.

**Shop till, offline mode** (local database for speed, syncs to the online one):

```ini
sync.mode='offline'
sync.siteName='Shop till'
sync.idleMinutes=30
sync.lockTimeoutMinutes=30

database.cloud.hostname='100.101.102.103'
database.cloud.port=3306
database.cloud.database='drawnonward'
database.cloud.username='admin'
database.cloud.password='choose-the-pos-password'
database.cloud.DBDriver='MySQLi'
database.cloud.DBPrefix='drawnonward_'
database.cloud.encrypt=false
```

`database.default.*` stays as it is (the local database). With a managed service (Option A) use its host name, port, user and `database.cloud.encrypt=true` instead of the Tailscale address. Give every offline-mode PC its own `sync.siteName`.

**Home PC, online mode** (no local data, everything on the online database). Online mode talks to the online database over the plain `database.default` connection, so it suits the Tailscale VM (Option B); with a managed service (Option A) run every PC in offline mode instead:

```ini
sync.mode='online'
sync.siteName='Home PC'
database.default.hostname='100.101.102.103'
database.default.database='drawnonward'
database.default.username='admin'
database.default.password='choose-the-pos-password'
```

With Docker, the `database.default.*` values are overridden by the `MYSQL_*` variables in `docker-compose.yml`; for an online-mode Docker install set `MYSQL_HOST_NAME`, `MYSQL_USERNAME`, `MYSQL_PASSWORD` and `MYSQL_DB_NAME` there instead. Online-mode pages take longer than local ones because every query crosses the internet (one to three seconds per page on a good connection).

After changing `.env`, Docker installs need `docker compose restart drawnonward`.

### First sync from an existing install

If one PC already has your data, set it to offline mode first. Its next login takes the lock and sets up an empty online database with the full schema and the migration history; **Sync now** (or logging out) then copies the data up. Every other PC is then set up as a new install in either mode and receives the data on its first login.

---

## 3. Daily use

The top bar of every page shows the state: *Online mode*, or in offline mode *This PC holds the data since 09:12 · Last sync 09:40*, with the **Sync now** and **Pull latest** buttons. **Configuration → Sync** shows the same plus the online database connection test, who holds the lock, and the recent sync history.

| Situation | What happens |
| --- | --- |
| Log in on an offline-mode PC while nobody holds the data | The lock is taken, the latest snapshot is pulled, you work locally. |
| Log in anywhere while another PC holds the data | Refused: "Shop till (admin) has been working offline since 09:12. Log out there first." |
| Press **Sync now** | Local snapshot replaces the online data (allowed only for the PC holding the lock). |
| Log out, or 30 minutes without activity | Offline mode syncs and releases the lock, then logs out. Online mode just logs out. |
| Internet drops while an offline-mode PC holds the data | It keeps working and can even log in again; the status bar says *Working offline*. Sync resumes when the connection is back. |
| Internet drops on an online-mode PC | It cannot log in or work until the connection is back, by design. |
| A PC that holds the data is switched off without logging out | After 30 minutes without a heartbeat the lock counts as **stale**. The login page then shows administrators a **Take over the data** button. Taking over clears the lock; the switched-off PC's unsynced work is not merged and stays on that PC (see below). |
| Press **Pull latest** (offline mode, not holding the data) | Replaces the local data with the online copy, after a confirmation. |

### Recovering unsynced work after a take-over

When another site takes the data over, the first PC can no longer sync (its heartbeat shows *Another site has taken over the data*). Its local work is still there: an administrator opens **Configuration → Sync → Download local snapshot** to save it as an SQL file, which drawnonward can merge by hand. Then log out and in again to pull the current data.

---

## 4. Troubleshooting

| Message | Cause and fix |
| --- | --- |
| *The online database cannot be reached and this PC does not hold the data* | Internet is down, or `database.cloud.*` is wrong: host name, port, password, `encrypt` (managed services need `true`), a wrong `sslCa` file, or the shop's address is not in the provider's IP allowlist. Check **Configuration → Sync → Test connection** from a PC that can log in. |
| *has been working offline since ...* | Normal: log out on that PC first. |
| *holds the data but has shown no activity since ...* | That PC stopped syncing (switched off, crashed). Log in as an administrator and use **Take over the data**. |
| *The online database is at software version X and this install at Y* | Update both installs to the same release before syncing (`git pull` and `docker compose up --build -d`). |
| Online mode pages are slow | Expected over the internet; use offline mode on the till and online mode only for occasional work, or run the POS itself on the VM (same Docker setup, open it in a browser over Tailscale). |
