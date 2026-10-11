# Running drawnonward POS on a Windows PC

This guide covers two ways to run the point of sale on a Windows 10 or Windows 11 PC:

- **Route A: with Docker Desktop.** Recommended. One command builds and starts everything; nothing else to install.
- **Route B: without Docker, using XAMPP.** Apache, MariaDB and PHP installed directly on Windows.

The [receipt printer](#receipt-printer-setup), [backup](#backups) and [troubleshooting](#troubleshooting) sections at the end apply to both routes.

Support: info@drawnonward.org · +923182232414

---

## Before you start

- A 64-bit PC with Windows 10 (version 2004 or later) or Windows 11, at least 8 GB of RAM, and an administrator account.
- A copy of this repository. Either install [Git for Windows](https://git-scm.com/download/win) and run `git clone <repository URL>`, or use **Code → Download ZIP** on GitHub and extract the ZIP.
- Put the folder somewhere short and without spaces, for example `C:\drawnonward-pos`. All commands below assume that folder.
- The default login after installation is username `admin` with password `pointofsale`. Change it right after the first login (click your name at the top of any page → Change Password).

To open PowerShell in the folder: open the folder in Explorer, click the address bar, type `powershell` and press Enter.

---

## Route A: with Docker Desktop (recommended)

### A1. Install Docker Desktop

1. Download Docker Desktop for Windows from https://www.docker.com/products/docker-desktop/ and run the installer. Keep **Use WSL 2 instead of Hyper-V** ticked.
2. Restart the PC if the installer asks. If Windows shows a message about the **WSL 2 kernel update**, follow the link it gives, install the update, then start Docker Desktop again.
3. Start Docker Desktop and wait until the whale icon in the taskbar stops animating.
4. In Docker Desktop go to **Settings → General** and tick **Start Docker Desktop when you sign in**. This is what brings the POS back after a reboot.

If Docker Desktop refuses to start, virtualization is usually disabled in the BIOS/UEFI (look for *Intel VT-x*, *AMD-V* or *SVM Mode* and enable it).

### A2. Create the settings file

In PowerShell, inside `C:\drawnonward-pos`:

```powershell
Copy-Item .env.example .env
```

The defaults in `.env` are correct for Docker. The encryption keys are generated and written into this file on the first start, so keep the file: it is part of your backups.

### A3. Optional: adjust `docker-compose.yml`

Open `docker-compose.yml` in Notepad if any of these apply:

- **Other devices will open the POS** (a second till, a tablet, another PC). Find the line `- ALLOWED_HOSTNAMES=localhost` and add the PC's network name and/or IP address, separated by commas, for example `- ALLOWED_HOSTNAMES=localhost,POS-PC,192.168.1.50`. The app refuses requests for host names that are not on this list.
- **Port 80 is already used** on this PC (Skype, IIS, another web server). Change `- "80:80"` to `- "8080:80"` and add `localhost:8080` to `ALLOWED_HOSTNAMES`. The POS is then at http://localhost:8080.
- **Change the database password.** Edit `MYSQL_PASSWORD=pointofsale` here and `MYSQL_PASSWORD=pointofsale` in `docker\docker-mysql.yml` to the same new value, before the first start.

### A4. Build and start

```powershell
docker compose up --build -d
```

The first run downloads about 1 GB and builds the application image. Expect 5 to 15 minutes depending on the internet connection. Later starts take seconds.

Check that both containers are running:

```powershell
docker compose ps
```

You should see `mysql` as `Up (healthy)` and `drawnonward-pos-drawnonward-1` as `Up`.

### A5. First login

1. Open http://localhost in Chrome or Edge.
2. The login page says **Initialization Required**. Click **Initialize**. This creates the database tables and takes up to a minute.
3. Log in with `admin` / `pointofsale`.
4. Change the admin password: click your name at the top → Change Password.
5. Set up the business: **Configuration** → company name, address, phone, logo, receipt template and font size, taxes, currency and date format.
6. Create staff accounts under **Employees**; grant each one only the modules they need.

### A6. Day-to-day operation

- The POS starts automatically with Windows as long as Docker Desktop is set to start at sign-in (step A1.4). Open http://localhost.
- Stop and start by hand:

  ```powershell
  docker compose stop
  docker compose start
  ```

- `docker compose down` removes the containers but **keeps** the database, uploads and logs (they live in Docker volumes). Never run `docker compose down -v`: the `-v` deletes the database.
- Logs: `docker compose logs -f drawnonward` (press Ctrl+C to stop following).

### A7. Updating to a new version

```powershell
git pull
docker compose up --build -d
```

If you installed from a ZIP, extract the new ZIP over the folder but keep your `.env`. Database changes are applied automatically on the next login.

---

## Route B: without Docker (XAMPP)

XAMPP bundles Apache, MariaDB and PHP for Windows. There are two ways to get a runnable copy of the application:

- **B-package**: use the release package `drawnonward.zip` supplied by drawnonward. It already contains the PHP libraries and the built assets. Use this for shop PCs.
- **B-source**: build from this repository on the PC. Requires Composer and Node.js and an internet connection. Use this for development.

### B1. Install XAMPP

1. Download **XAMPP for Windows with PHP 8.2** from https://www.apachefriends.org/ and install it to `C:\xampp`. Apache and MySQL (MariaDB) are the only components the POS needs.
2. Open the **XAMPP Control Panel** (run it as administrator so it can later install the services).

### B2. Enable the PHP extensions

1. In the Control Panel click **Config** next to Apache → **PHP (php.ini)**.
2. Find each of these lines and remove the `;` at the start if present, so they read exactly:

   ```ini
   extension=intl
   extension=gd
   extension=mysqli
   extension=mbstring
   extension=curl
   extension=openssl
   ```

   `intl` is the one XAMPP ships disabled; the others are usually already enabled.
3. Save the file. If Apache was running, stop and start it.

### B3. Put the application in place

**B-package:** extract `drawnonward.zip` so that the file `C:\xampp\htdocs\drawnonward\public\index.php` exists.

**B-source:**

1. Install [Git for Windows](https://git-scm.com/download/win), [Composer](https://getcomposer.org/download/) (the Windows installer asks for the PHP executable: choose `C:\xampp\php\php.exe`) and [Node.js 20 LTS](https://nodejs.org/).
2. Clone the repository into `C:\xampp\htdocs\drawnonward`.
3. Open PowerShell in that folder and run, one after the other:

   ```powershell
   composer install --no-dev
   npm ci
   npm run build
   ```

   The build takes a few minutes and needs an internet connection. It also records the licences of the bundled libraries, which calls `composer`, so Composer must be on the PATH (the installer does this).

### B4. Point Apache at the `public` folder

The web server must serve the `public` folder, never the application root.

1. In the Control Panel click **Config** next to Apache → **Apache (httpd.conf)**.
2. Change

   ```apache
   DocumentRoot "C:/xampp/htdocs"
   <Directory "C:/xampp/htdocs">
   ```

   to

   ```apache
   DocumentRoot "C:/xampp/htdocs/drawnonward/public"
   <Directory "C:/xampp/htdocs/drawnonward/public">
   ```

3. Make sure the same `<Directory>` block contains `AllowOverride All` (XAMPP's default) and that the line `LoadModule rewrite_module modules/mod_rewrite.so` is not commented out (also the default).
4. Save and restart Apache from the Control Panel.

phpMyAdmin stays reachable at http://localhost/phpmyadmin because XAMPP maps it separately.

### B5. Create the database and a database user

1. Start **Apache** and **MySQL** in the Control Panel.
2. Open http://localhost/phpmyadmin.
3. **Databases** tab → database name `drawnonward`, collation `utf8mb4_general_ci` → **Create**.
4. **User accounts** tab → **Add user account**: user name `admin`, host name `localhost`, choose a strong password and note it. Under **Database for user account** leave the boxes unticked, click **Go**.
5. Open the new user → **Database** tab → select `drawnonward` → **Go** → tick **Check all** under Database-specific privileges → **Go**.

### B6. Configure `.env`

1. In `C:\xampp\htdocs\drawnonward` copy `.env.example` to `.env` (PowerShell: `Copy-Item .env.example .env`).
2. Open `.env` in Notepad and set:

   ```ini
   CI_ENVIRONMENT=production
   app.allowedHostnames='localhost'
   database.default.hostname='localhost'
   database.default.database='drawnonward'
   database.default.username='admin'
   database.default.password='the password from step B5'
   ```

   If other devices will open the POS, add the PC's network name and IP address: `app.allowedHostnames='localhost,POS-PC,192.168.1.50'`.
3. Leave `encryption.key` and `throttle.key` empty. They are generated and written into this file on the first page load.

### B7. First login

Open http://localhost. The login page says **Initialization Required**: click **Initialize**, wait for the tables to be created, then log in with `admin` / `pointofsale` and change the password. Continue with the setup steps listed under A5.

### B8. Start with Windows

In the XAMPP Control Panel (running as administrator) tick the **Service** checkbox in front of Apache and of MySQL. Both then start as Windows services at boot, before anyone logs in.

### B9. Updating

- **B-package:** back up first (see below), then extract the new package over the folder, keeping your `.env` and the `public\uploads` folder.
- **B-source:** in PowerShell run `git pull`, then `composer install --no-dev`, `npm ci`, `npm run build`.

Database changes are applied automatically on the next login.

---

## Receipt printer setup

Receipts print through the browser's normal print function, so any thermal printer with a Windows driver works (Epson TM series, Star, Xprinter, Rongta and similar, 80 mm or 58 mm).

1. Install the printer's Windows driver and set the paper width in the driver's **Printing preferences** (80 mm or 58 mm; choose a "receipt" or variable-length paper size if the driver offers one, so the printer cuts after the content instead of feeding a full page).
2. Make it the Windows **default printer** (Settings → Bluetooth & devices → Printers & scanners).
3. In the POS, complete a sale, then click **Print** on the receipt page. In the browser's print dialog select the thermal printer, set **Margins** to *None* or *Minimum*, and untick **Headers and footers**. Chrome and Edge remember these choices for the site.
4. To print the receipt automatically after every sale, tick **Print after Sale** in the sales register.
5. For printing without any dialog, start the browser in kiosk-printing mode. Create a desktop shortcut with this target (adjust the path if the browser is installed elsewhere):

   ```text
   "C:\Program Files\Google\Chrome\Application\chrome.exe" --kiosk-printing --app=http://localhost
   ```

   For Edge:

   ```text
   "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --kiosk-printing --app=http://localhost
   ```

   `--kiosk-printing` sends every print job straight to the default printer with the settings last used in the print dialog, and `--app` opens the POS as its own window without browser toolbars. Use this shortcut to open the POS on the till.

---

## Working from more than one place

The POS can be used from the shop and from home with one shared online database, in an online mode (every install works directly on the online database) or an offline mode (the till works on its own database and syncs whole snapshots, one site at a time). Everyone is logged out automatically after 30 minutes without activity. Setup, the Oracle Cloud free virtual machine, the `.env` settings and the daily rules are in [ONLINE.md](ONLINE.md).

---

## Backups

Three things must leave the PC regularly: the database, the uploaded images (`public\uploads`) and the `.env` file, which holds the encryption keys. Without `.env`, encrypted settings such as the SMTP password in a restored database cannot be read. The scripts in `tools\backup` do all of this.

### What `backup.ps1` does

1. Dumps the database, copies the uploads and `.env`, and writes a small manifest (date, PC name, app version).
2. Packs them into `backups\drawnonward-backup-<date>-<time>.zip` and re-opens the archive to check it is complete.
3. Copies the archive off the PC: to any cloud through rclone (`-Remote`), into a folder that OneDrive, Google Drive or Dropbox already syncs (`-SyncFolder`), or both.
4. Deletes local archives older than 14 days and cloud archives older than 180 days (`-KeepDays`, `-CloudKeepDays`).
5. Appends the result to `backups\backup.log`. Exit code 0 means success, which Task Scheduler shows as `0x0`.

Credentials are never stored in the script: the Docker install asks the database container for its own credentials, the XAMPP install reads them from `.env`.

### One-time cloud setup

Pick one. Option 1 encrypts the archives before they leave the PC and is the recommended choice.

**Option 1: rclone with encryption (Google Drive, OneDrive, Dropbox, S3, Backblaze B2 and others)**

1. Install rclone: in PowerShell run `winget install Rclone.Rclone`, then open a new PowerShell window.
2. Run `rclone config`, choose **n** (new remote), name it `gdrive`, pick your provider from the list (for example `drive` for Google Drive or `onedrive`) and follow the prompts; a browser window opens to sign in.
3. Run `rclone config` again, choose **n**, name it `gdrive-crypt`, type `crypt`, and when asked for the remote enter `gdrive:drawnonward-backups`. Set a password when asked. **Write this password down and keep it outside the PC**: without it the backups cannot be opened, not even by drawnonward.
4. Test with `rclone lsd gdrive-crypt:` (no error means it works).

Use `-Remote gdrive-crypt:drawnonward-backups` in the commands below.

**Option 2: synced folder (no encryption)**

Install the OneDrive, Google Drive or Dropbox desktop app, sign in, and create a folder named `drawnonward-backups` inside the synced folder. Use `-SyncFolder "$env:USERPROFILE\OneDrive\drawnonward-backups"` (adjust the path) in the commands below. Anyone with access to that cloud account can read the data, so protect the account with a strong password and two-factor authentication.

### Run a backup and schedule it

If PowerShell refuses to run scripts, run this once: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

```powershell
cd C:\drawnonward-pos\tools\backup

# run one backup now
.\backup.ps1 -Remote gdrive-crypt:drawnonward-backups

# run it every day at 21:00
.\schedule-backup.ps1 -Time 21:00 -Remote gdrive-crypt:drawnonward-backups
```

For the synced-folder option replace `-Remote ...` with `-SyncFolder "$env:USERPROFILE\OneDrive\drawnonward-backups"`. XAMPP installs add `-Mode Xampp` to both commands.

The scheduled task runs as the logged-on user, because Docker Desktop lives in that session; if the PC was off at 21:00, the backup runs at the next logon. Check it in Task Scheduler (task "drawnonward POS backup", Last Run Result `0x0`) or in `backups\backup.log`. Run `.\schedule-backup.ps1 -Unregister` to remove the task.

### Restore

```powershell
cd C:\drawnonward-pos\tools\backup
.\restore.ps1 -Backup C:\Users\Shop\Downloads\drawnonward-backup-20261003-210000.zip
```

This replaces the current database and uploads after a confirmation. Add `-IncludeEnv` to restore the `.env` file as well, and `-Force` to skip the confirmation. To fetch an archive from the cloud: `rclone copy gdrive-crypt:drawnonward-backups/drawnonward-backup-20261003-210000.zip .` or copy it out of the synced folder.

### Disaster recovery on a new PC

1. Install Docker Desktop (A1) and get the code (Before you start). Do **not** create `.env` from the example.
2. Fetch the latest backup zip from the cloud and extract the `.env` file from it into the project folder (it is a hidden file; in Explorer turn on **View → Show → Hidden items**).
3. Run `docker compose up --build -d` and wait until `docker compose ps` shows `mysql` as healthy.
4. Run `.\restore.ps1 -Backup <path to the zip> -Force` from `tools\backup`.
5. Open http://localhost, log in with the old user names and passwords, and check a recent sale, the company logo and the receipt settings.

Keep the rclone password and the cloud account details in a password manager, never only on the till PC.

---

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `Security: allowedHostnames is not configured` | Route A: `ALLOWED_HOSTNAMES` missing in `docker-compose.yml`. Route B: `.env` missing or `app.allowedHostnames` empty. |
| Pages redirect to `http://localhost/...` and show another site or a 404 | The host name or port you typed is not in the allowed list. Add it (see A3 or B6), including the port if you use one, for example `localhost:8080`. |
| Route A: `docker compose up` fails with "port is already allocated" | Something else uses port 80. Follow A3 to move the POS to port 8080. |
| Route A: Docker Desktop will not start | Enable virtualization in the BIOS/UEFI, install the WSL 2 kernel update when prompted, reboot. |
| Route A: "Unable to connect to the database" right after starting | MariaDB is still starting. Wait 30 seconds and reload. |
| Route B: Apache will not start on port 80 | Another program holds port 80 (Skype, IIS "World Wide Web Publishing Service"). Stop it, or change `Listen 80` to `Listen 8080` in httpd.conf and use http://localhost:8080 (add `localhost:8080` to `app.allowedHostnames`). |
| Route B: error mentioning `intl`, `IntlDateFormatter` or `NumberFormatter` | `extension=intl` is still commented out in php.ini (step B2). Restart Apache after the change. |
| Route B: blank page, or every page except the login gives a 404 | `DocumentRoot` not pointing at `public`, or `AllowOverride`/`mod_rewrite` disabled (step B4). |
| Route B: "system folder missing" or a page about a missing `vendor` folder | The copy was not built. Use the release package, or run the three build commands from B3. |
| Receipt prints with the date and a URL at the top or bottom | Untick **Headers and footers** in the browser's print dialog once. |
| Receipt prints on a full A4 page | Select the thermal printer and its receipt paper size in the print dialog, and set it as the default printer. |

To see detailed error messages while troubleshooting, set `CI_ENVIRONMENT=development` (in `docker-compose.yml` for Route A, in `.env` for Route B), reproduce the problem, then set it back to `production`.

---

## For drawnonward: building the release package

The release package for Route B is produced from a clean checkout **without** a `.env` file, on any machine with Docker:

```bash
docker run --rm -v "${PWD}:/app" -w /app composer:2 sh -c "apk add --no-cache nodejs npm && composer install --no-dev --no-interaction --ignore-platform-reqs && npm ci && npm run build && npx gulp compress"
```

The result is `dist/drawnonward.zip` (and `dist/drawnonward.tar`), containing the application, the PHP libraries and the built assets. Ship the zip to clients who install without Docker.
