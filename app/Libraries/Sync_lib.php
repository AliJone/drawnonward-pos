<?php

namespace App\Libraries;

use App\Models\Employee;
use CodeIgniter\Database\BaseConnection;
use Config\Database;
use Config\Sync;
use RuntimeException;
use Throwable;

/**
 * Multi-site operation.
 *
 * Online mode works directly on the shared database. Offline mode works on the local database under a
 * lock that lives in the shared database, and moves whole snapshots (every POS table plus the uploaded
 * images) between the two. The lock is what keeps a snapshot push from overwriting somebody else's work:
 * only the site holding it may push, and online-mode logins are refused while it is held.
 */
class Sync_lib
{
    public const MODE_STANDALONE = 'standalone';
    public const MODE_ONLINE = 'online';
    public const MODE_OFFLINE = 'offline';

    // Tables that describe one install and never travel in a snapshot
    private const LOCAL_ONLY_TABLES = ['sessions', 'migrations', 'sync_state', 'sync_log', 'sync_files'];
    private const CHUNK = 1000;

    private Sync $config;
    private BaseConnection $local;
    private ?BaseConnection $cloud = null;

    public function __construct()
    {
        $this->config = config(Sync::class);
        $this->local = Database::connect();
    }

    public function mode(): string
    {
        return in_array($this->config->mode, [self::MODE_ONLINE, self::MODE_OFFLINE], true) ? $this->config->mode : self::MODE_STANDALONE;
    }

    public function isOnline(): bool
    {
        return $this->mode() === self::MODE_ONLINE;
    }

    public function isOffline(): bool
    {
        return $this->mode() === self::MODE_OFFLINE;
    }

    public function siteName(): string
    {
        return $this->config->siteName !== '' ? $this->config->siteName : (string) gethostname();
    }

    /**
     * The connection that holds the lock and the shared snapshot. In online mode that is the working database.
     */
    public function cloud(): BaseConnection
    {
        if ($this->cloud === null) {
            $connection = $this->isOnline() ? $this->local : Database::connect('cloud');
            $connection->initialize();
            $this->cloud = $connection;
        }

        return $this->cloud;
    }

    public function cloudReachable(): bool
    {
        try {
            $this->cloud();

            return true;
        } catch (Throwable $e) {
            return false;
        }
    }

    // ------------------------------------------------------------------ login paths

    /**
     * Online mode: a site working offline owns the data, so the shared database must not be changed.
     *
     * @return string|null message explaining the refusal, null when login may proceed
     */
    public function onlineLoginBlock(string $username, string $password, bool $takeOver = false): ?string
    {
        $state = $this->stateRow($this->cloud());
        if ($state->holder_site === null) {
            return null;
        }

        $stale = $this->isStale($state);
        if ($takeOver && $stale && $this->cloudCredentialsValid($username, $password) && $this->isCloudAdmin($username)) {
            $this->takeOver($username);

            return null;
        }
        $this->offerTakeOver($stale);

        return lang($stale ? 'Sync.login_held_stale' : 'Sync.login_held', $this->holderArgs($state));
    }

    /**
     * Remembered for the login page, which then shows the take-over button to administrators.
     */
    private function offerTakeOver(bool $stale): void
    {
        session()->set('sync_take_over_offer', $stale);
    }

    /**
     * Administrator according to the shared database: the first employee, or one holding every admin module.
     */
    public function isCloudAdmin(string $username): bool
    {
        $cloud = $this->cloud();
        if (!$cloud->tableExists('employees')) {
            return true;
        }
        $row = $cloud->table('employees')->getWhere(['username' => $username, 'deleted' => 0], 1)->getRow();
        if ($row === null) {
            return false;
        }
        if ((int) $row->person_id === 1) {
            return true;
        }
        $granted = $cloud->table('grants')->where('person_id', $row->person_id)->whereIn('permission_id', ADMIN_MODULES)->countAllResults();

        return $granted === count(ADMIN_MODULES);
    }

    /**
     * Offline mode login: credentials are checked against the shared database, the lock is taken, and
     * a fresh snapshot is pulled whenever the lock was free (anything may have changed meanwhile).
     *
     * @return array{ok: bool, message: string}
     */
    public function offlineLogin(string $username, string $password, bool $takeOver = false): array
    {
        $employee = model(Employee::class);

        if (!$this->cloudReachable()) {
            if (!$this->holdsLockLocally()) {
                return ['ok' => false, 'message' => lang('Sync.cloud_unreachable')];
            }
            if (!$employee->login($username, $password)) {
                return ['ok' => false, 'message' => lang('Login.invalid_username_and_password')];
            }
            session()->set('sync_working_offline', true);

            return ['ok' => true, 'message' => ''];
        }

        if (!$this->cloudCredentialsValid($username, $password)) {
            return ['ok' => false, 'message' => lang('Login.invalid_username_and_password')];
        }

        $lock = $this->acquireLock($username);
        if (!$lock['ok'] && $takeOver && $lock['stale'] && $this->isCloudAdmin($username)) {
            $this->takeOver($username);
            $lock = ['ok' => true, 'acquired' => false, 'stale' => false, 'holder' => null];
        }
        if (!$lock['ok']) {
            $this->offerTakeOver($lock['stale']);

            return ['ok' => false, 'message' => lang($lock['stale'] ? 'Sync.login_held_stale' : 'Sync.login_held', $this->holderArgs($lock['holder']))];
        }

        if ($lock['acquired'] && $this->cloudHasSnapshot()) {
            $this->pull('login');
        }

        if (!$employee->login($username, $password)) {
            if ($lock['acquired']) {
                $this->releaseLock();
            }

            return ['ok' => false, 'message' => lang('Login.invalid_username_and_password')];
        }
        session()->remove('sync_working_offline');

        return ['ok' => true, 'message' => ''];
    }

    /**
     * Offline mode session end (logout or idle): push and release. Failures are logged, never block the logout;
     * the lock then stays with this site and its data stays local.
     */
    public function endSession(string $trigger): void
    {
        if (!$this->isOffline() || !$this->holdsLockLocally()) {
            return;
        }

        try {
            $this->push($trigger);
            $this->releaseLock();
        } catch (Throwable $e) {
            log_message('warning', 'Sync at ' . $trigger . ' failed, this site keeps the data: ' . $e->getMessage());
            $this->log($trigger, 'failed', $e->getMessage());
        }
    }

    // ------------------------------------------------------------------ lock

    /**
     * @return array{ok: bool, acquired: bool, stale: bool, holder: ?object}
     */
    public function acquireLock(string $username): array
    {
        $cloud = $this->cloud();
        $cloud->transBegin();

        try {
            $state = $this->stateRow($cloud, true);
            $now = self::now();

            if ($state->holder_site !== null && $state->holder_site !== $this->siteName()) {
                $stale = $this->isStale($state);
                $cloud->transRollback();

                return ['ok' => false, 'acquired' => false, 'stale' => $stale, 'holder' => $state];
            }

            $acquired = $state->holder_site === null;
            $generation = $acquired ? (int) $state->holder_generation + 1 : (int) $state->holder_generation;
            $holder = [
                'holder_site'       => $this->siteName(),
                'holder_user'       => $username,
                'holder_generation' => $generation,
                'acquired_at'       => $acquired ? $now : $state->acquired_at,
                'last_seen_at'      => $now,
            ];
            $cloud->table('sync_state')->where('id', 1)->update($holder);
            $cloud->transCommit();
        } catch (Throwable $e) {
            $cloud->transRollback();

            throw $e;
        }

        $this->updateLocalState($holder);

        return ['ok' => true, 'acquired' => $acquired, 'stale' => false, 'holder' => null];
    }

    /**
     * Administrator takes the data over from a site that stopped syncing. The old holder's generation is
     * invalidated, so a later push from it is refused and its unsynced work stays on that PC.
     */
    public function takeOver(string $username): void
    {
        $cloud = $this->cloud();
        $state = $this->stateRow($cloud, true);
        $now = self::now();
        $previous = $state->holder_site ?? '';
        $holder = [
            'holder_site'       => $this->isOffline() ? $this->siteName() : null,
            'holder_user'       => $this->isOffline() ? $username : null,
            'holder_generation' => (int) $state->holder_generation + 1,
            'acquired_at'       => $this->isOffline() ? $now : null,
            'last_seen_at'      => $this->isOffline() ? $now : null,
        ];
        $cloud->table('sync_state')->where('id', 1)->update($holder);

        if ($this->isOffline()) {
            $this->updateLocalState($holder);
            if ($this->cloudHasSnapshot()) {
                $this->pull('takeover');
            }
        }
        $this->log('takeover', 'ok', 'Taken over from ' . $previous . ' by ' . $username);
    }

    /**
     * Keeps the lock alive. Returns false when another site has taken the data over.
     */
    public function heartbeat(): bool
    {
        if (!$this->isOffline() || !$this->holdsLockLocally()) {
            return true;
        }

        $local = $this->stateRow($this->local);
        $cloud = $this->cloud();
        $state = $this->stateRow($cloud);
        if ($state->holder_site !== $this->siteName() || (int) $state->holder_generation !== (int) $local->holder_generation) {
            $this->updateLocalState($this->emptyHolder());

            return false;
        }
        $cloud->table('sync_state')->where('id', 1)->update(['last_seen_at' => self::now()]);

        return true;
    }

    public function releaseLock(): void
    {
        $local = $this->stateRow($this->local);
        $this->cloud()->table('sync_state')
            ->where(['id' => 1, 'holder_site' => $this->siteName(), 'holder_generation' => (int) $local->holder_generation])
            ->update($this->emptyHolder());
        $this->updateLocalState($this->emptyHolder());
    }

    public function holdsLockLocally(): bool
    {
        $local = $this->stateRow($this->local);

        return $local->holder_site === $this->siteName();
    }

    // ------------------------------------------------------------------ snapshots

    /**
     * Local snapshot replaces the shared one. Requires the lock.
     *
     * @return array{tables: int, files: int}
     */
    public function push(string $trigger): array
    {
        $started = self::now();
        $cloud = $this->cloud();
        $this->ensureCloudSchema();
        $this->assertSameSchemaVersion();

        $local = $this->stateRow($this->local);
        $cloud->transBegin();

        try {
            $state = $this->stateRow($cloud, true);
            if ($state->holder_site !== $this->siteName() || (int) $state->holder_generation !== (int) $local->holder_generation) {
                throw new RuntimeException(lang('Sync.lock_lost'));
            }

            $tables = $this->copyTables($this->local, $cloud);
            $now = self::now();
            $version = (int) $state->snapshot_version + 1;
            $cloud->table('sync_state')->where('id', 1)->update([
                'snapshot_version'   => $version,
                'snapshot_pushed_at' => $now,
                'snapshot_site'      => $this->siteName(),
                'last_seen_at'       => $now,
            ]);
            $cloud->transCommit();
        } catch (Throwable $e) {
            $cloud->transRollback();
            $this->log($trigger . ' push', 'failed', $e->getMessage(), $started);

            throw $e;
        }

        $files = $this->pushFiles();
        $this->updateLocalState(['snapshot_version' => $version, 'snapshot_pushed_at' => $now, 'snapshot_site' => $this->siteName()]);
        $this->log($trigger . ' push', 'ok', lang('Sync.push_done', [$tables, $files]), $started);

        return ['tables' => $tables, 'files' => $files];
    }

    /**
     * Shared snapshot replaces the local one.
     *
     * @return array{tables: int, files: int}
     */
    public function pull(string $trigger): array
    {
        $started = self::now();
        $cloud = $this->cloud();
        $this->assertSameSchemaVersion();

        try {
            $state = $this->stateRow($cloud);
            $tables = $this->copyTables($cloud, $this->local);
            $files = $this->pullFiles();
        } catch (Throwable $e) {
            $this->log($trigger . ' pull', 'failed', $e->getMessage(), $started);

            throw $e;
        }

        $this->updateLocalState([
            'snapshot_version'   => (int) $state->snapshot_version,
            'snapshot_pushed_at' => $state->snapshot_pushed_at,
            'snapshot_site'      => $state->snapshot_site,
        ]);
        $this->log($trigger . ' pull', 'ok', lang('Sync.pull_done', [$tables, $files]), $started);

        return ['tables' => $tables, 'files' => $files];
    }

    /**
     * Local tables as INSERT statements, for recovering work that can no longer be pushed.
     */
    public function exportLocalSql(): string
    {
        $out = "-- drawnonward POS local snapshot of " . $this->siteName() . ' at ' . self::now() . "\nSET FOREIGN_KEY_CHECKS = 0;\n";
        foreach ($this->syncTables($this->local) as $table) {
            $full = $this->local->protectIdentifiers($this->local->prefixTable($table));
            $out .= "DELETE FROM $full;\n";
            foreach ($this->local->table($table)->get()->getResultArray() as $row) {
                $columns = implode(', ', array_map(fn ($c) => $this->local->protectIdentifiers($c), array_keys($row)));
                $values = implode(', ', array_map(fn ($v) => $v === null ? 'NULL' : $this->local->escape($v), array_values($row)));
                $out .= "INSERT INTO $full ($columns) VALUES ($values);\n";
            }
        }

        return $out . "SET FOREIGN_KEY_CHECKS = 1;\n";
    }

    // ------------------------------------------------------------------ status

    /**
     * What the top bar and the Sync tab show. $withCloud adds the shared state (one extra connection).
     */
    public function status(bool $withCloud): array
    {
        $local = $this->isStandalone() ? null : $this->stateRow($this->local);
        $status = [
            'mode'            => $this->mode(),
            'site'            => $this->siteName(),
            'holds_lock'      => $local !== null && $local->holder_site === $this->siteName(),
            'held_since'      => self::display($local->acquired_at ?? null),
            'last_sync'       => self::display($local->snapshot_pushed_at ?? null),
            'working_offline' => (bool) session()->get('sync_working_offline'),
            'cloud_reachable' => null,
            'holder'          => null,
            'holder_stale'    => false,
            'cloud_version'   => null,
            'local_version'   => $local->snapshot_version ?? null,
        ];

        if ($withCloud && !$this->isStandalone()) {
            $status['cloud_reachable'] = $this->cloudReachable();
            if ($status['cloud_reachable']) {
                $state = $this->stateRow($this->cloud());
                $status['holder'] = $state->holder_site === null ? null : $this->holderArgs($state);
                $status['holder_stale'] = $state->holder_site !== null && $this->isStale($state);
                $status['cloud_version'] = (int) $state->snapshot_version;
                $status['cloud_pushed_at'] = self::display($state->snapshot_pushed_at);
            }
        }

        return $status;
    }

    public function recentLog(int $limit = 20): array
    {
        if ($this->isStandalone()) {
            return [];
        }
        $this->ensureSyncTables($this->local);

        return $this->local->table('sync_log')->orderBy('id', 'DESC')->get($limit)->getResultArray();
    }

    public function isStandalone(): bool
    {
        return $this->mode() === self::MODE_STANDALONE;
    }

    // ------------------------------------------------------------------ internals

    private function cloudCredentialsValid(string $username, string $password): bool
    {
        $cloud = $this->cloud();
        // An empty shared database is being set up from this install; the local check applies instead
        if (!$cloud->tableExists('employees')) {
            return true;
        }

        $row = $cloud->table('employees')->getWhere(['username' => $username, 'deleted' => 0], 1)->getRow();
        if ($row === null) {
            return false;
        }

        return ($row->hash_version === '1' && $row->password === md5($password))
            || ($row->hash_version === '2' && password_verify($password, $row->password));
    }

    private function cloudHasSnapshot(): bool
    {
        return $this->cloud()->tableExists('employees');
    }

    /**
     * Sync timestamps are stored in UTC so every site compares the same clock.
     */
    public static function now(): string
    {
        return gmdate('Y-m-d H:i:s');
    }

    public static function toTime(?string $utc): ?int
    {
        return $utc === null ? null : strtotime($utc . ' UTC');
    }

    public static function display(?string $utc): string
    {
        $time = self::toTime($utc);
        if ($time === null) {
            return '';
        }

        return function_exists('to_datetime') ? to_datetime($time) : date('Y-m-d H:i', $time);
    }

    private function isStale(object $state): bool
    {
        return $state->last_seen_at !== null
            && self::toTime($state->last_seen_at) < time() - $this->config->lockTimeoutMinutes * 60;
    }

    private function holderArgs(object $state): array
    {
        return [$state->holder_site, $state->holder_user, self::display($state->acquired_at), self::display($state->last_seen_at)];
    }

    private function emptyHolder(): array
    {
        return ['holder_site' => null, 'holder_user' => null, 'acquired_at' => null, 'last_seen_at' => null];
    }

    private function stateRow(BaseConnection $db, bool $forUpdate = false): object
    {
        $this->ensureSyncTables($db);
        $sql = 'SELECT * FROM ' . $db->protectIdentifiers($db->prefixTable('sync_state')) . ' WHERE id = 1' . ($forUpdate ? ' FOR UPDATE' : '');
        $row = $db->query($sql)->getRow();
        if ($row === null) {
            $db->table('sync_state')->insert(['id' => 1]);
            $row = $db->query($sql)->getRow();
        }

        return $row;
    }

    private function updateLocalState(array $fields): void
    {
        $this->stateRow($this->local);
        $this->local->table('sync_state')->where('id', 1)->update($fields);
    }

    private function log(string $action, string $status, string $message, ?string $started = null): void
    {
        try {
            $this->ensureSyncTables($this->local);
            $this->local->table('sync_log')->insert([
                'site'        => $this->siteName(),
                'action'      => $action,
                'status'      => $status,
                'message'     => mb_substr($message, 0, 1000),
                'started_at'  => $started ?? self::now(),
                'finished_at' => self::now(),
            ]);
        } catch (Throwable $e) {
            log_message('error', 'Sync log write failed: ' . $e->getMessage());
        }
    }

    /**
     * Creates the sync bookkeeping tables when missing. Also used by the migration.
     */
    public function ensureSyncTables(BaseConnection $db): void
    {
        if ($db->tableExists('sync_state')) {
            return;
        }
        $p = $db->DBPrefix;
        $db->query("CREATE TABLE IF NOT EXISTS `{$p}sync_state` (
            `id` TINYINT NOT NULL,
            `holder_site` VARCHAR(100) NULL,
            `holder_user` VARCHAR(255) NULL,
            `holder_generation` INT NOT NULL DEFAULT 0,
            `acquired_at` DATETIME NULL,
            `last_seen_at` DATETIME NULL,
            `snapshot_version` INT NOT NULL DEFAULT 0,
            `snapshot_pushed_at` DATETIME NULL,
            `snapshot_site` VARCHAR(100) NULL,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
        $db->query("CREATE TABLE IF NOT EXISTS `{$p}sync_log` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `site` VARCHAR(100) NOT NULL,
            `action` VARCHAR(50) NOT NULL,
            `status` VARCHAR(20) NOT NULL,
            `message` VARCHAR(1000) NOT NULL,
            `started_at` DATETIME NOT NULL,
            `finished_at` DATETIME NOT NULL,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
        $db->query("CREATE TABLE IF NOT EXISTS `{$p}sync_files` (
            `path` VARCHAR(255) NOT NULL,
            `size` INT NOT NULL,
            `modified_at` INT NOT NULL,
            `content` LONGBLOB NOT NULL,
            PRIMARY KEY (`path`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    }

    /**
     * An empty shared database gets the local schema (CREATE TABLE statements) and the migration history,
     * so the first push from an existing install sets it up.
     */
    private function ensureCloudSchema(): void
    {
        $cloud = $this->cloud();
        if ($cloud->tableExists('employees')) {
            return;
        }

        $cloud->query('SET FOREIGN_KEY_CHECKS = 0');
        try {
            foreach ($this->local->listTables() as $fullName) {
                if (strpos($fullName, $this->local->DBPrefix) !== 0) {
                    continue;
                }
                $table = substr($fullName, strlen($this->local->DBPrefix));
                if (in_array($table, ['sync_state', 'sync_log', 'sync_files'], true)) {
                    continue;
                }
                $create = $this->local->query('SHOW CREATE TABLE ' . $this->local->protectIdentifiers($fullName))->getRowArray();
                $sql = preg_replace('/^CREATE TABLE/', 'CREATE TABLE IF NOT EXISTS', $create['Create Table']);
                $sql = str_replace('`' . $fullName . '`', '`' . $cloud->prefixTable($table) . '`', $sql);
                $cloud->query($sql);
            }
            $rows = $this->local->table('migrations')->get()->getResultArray();
            if ($rows !== []) {
                $cloud->table('migrations')->emptyTable();
                $cloud->table('migrations')->insertBatch($rows);
            }
        } finally {
            $cloud->query('SET FOREIGN_KEY_CHECKS = 1');
        }
    }

    private function schemaVersion(BaseConnection $db): int
    {
        if (!$db->tableExists('migrations')) {
            return 0;
        }
        $row = $db->table('migrations')->selectMax('version')->get()->getRow();

        return (int) ($row->version ?? 0);
    }

    private function assertSameSchemaVersion(): void
    {
        $localVersion = $this->schemaVersion($this->local);
        $cloudVersion = $this->schemaVersion($this->cloud());
        if ($localVersion !== $cloudVersion) {
            throw new RuntimeException(lang('Sync.schema_mismatch', [$cloudVersion, $localVersion]));
        }
    }

    /**
     * Tables that travel in a snapshot: every prefixed table except the per-install ones.
     */
    private function syncTables(BaseConnection $db): array
    {
        $tables = [];
        foreach ($db->listTables() as $fullName) {
            if (strpos($fullName, $db->DBPrefix) !== 0) {
                continue;
            }
            $table = substr($fullName, strlen($db->DBPrefix));
            if (!in_array($table, self::LOCAL_ONLY_TABLES, true)) {
                $tables[] = $table;
            }
        }
        sort($tables);

        return $tables;
    }

    /**
     * Replaces every synced table in $dst with the rows from $src, in one transaction on $dst.
     */
    private function copyTables(BaseConnection $src, BaseConnection $dst): int
    {
        $tables = $this->syncTables($src);
        $dst->transBegin();
        $dst->query('SET FOREIGN_KEY_CHECKS = 0');

        try {
            foreach ($tables as $table) {
                if (!$dst->tableExists($table)) {
                    throw new RuntimeException(lang('Sync.schema_mismatch', ['?', '?']) . " ($table)");
                }
                $dst->table($table)->emptyTable();

                $keys = [];
                foreach ($src->getFieldData($table) as $field) {
                    if ($field->primary_key) {
                        $keys[] = $field->name;
                    }
                }
                $offset = 0;
                do {
                    $builder = $src->table($table);
                    foreach ($keys as $key) {
                        $builder->orderBy($key, 'ASC');
                    }
                    $rows = $builder->get(self::CHUNK, $offset)->getResultArray();
                    if ($rows !== []) {
                        $dst->table($table)->insertBatch($rows);
                    }
                    $offset += self::CHUNK;
                } while (count($rows) === self::CHUNK);
            }
            $dst->query('SET FOREIGN_KEY_CHECKS = 1');
            $dst->transCommit();
        } catch (Throwable $e) {
            $dst->transRollback();
            $dst->query('SET FOREIGN_KEY_CHECKS = 1');

            throw $e;
        }

        return count($tables);
    }

    private function uploadsPath(): string
    {
        return rtrim(FCPATH, '/\\') . DIRECTORY_SEPARATOR . 'uploads';
    }

    /**
     * Uploaded images travel through the sync_files table of the shared database.
     */
    private function pushFiles(): int
    {
        $cloud = $this->cloud();
        $this->ensureSyncTables($cloud);
        $existing = [];
        foreach ($cloud->table('sync_files')->select('path, size, modified_at')->get()->getResultArray() as $row) {
            $existing[$row['path']] = $row;
        }

        $seen = [];
        $count = 0;
        $base = $this->uploadsPath();
        foreach (new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator($base, \FilesystemIterator::SKIP_DOTS)) as $file) {
            if (!$file->isFile() || in_array($file->getFilename(), ['.gitignore', '.gitkeep', 'index.html'], true)) {
                continue;
            }
            $path = str_replace('\\', '/', substr($file->getPathname(), strlen($base) + 1));
            $seen[$path] = true;
            $row = $existing[$path] ?? null;
            if ($row !== null && (int) $row['size'] === $file->getSize() && (int) $row['modified_at'] === $file->getMTime()) {
                continue;
            }
            $data = ['path' => $path, 'size' => $file->getSize(), 'modified_at' => $file->getMTime(), 'content' => file_get_contents($file->getPathname())];
            if ($row === null) {
                $cloud->table('sync_files')->insert($data);
            } else {
                $cloud->table('sync_files')->where('path', $path)->update($data);
            }
            $count++;
        }
        foreach (array_diff_key($existing, $seen) as $path => $row) {
            $cloud->table('sync_files')->where('path', $path)->delete();
        }

        return $count;
    }

    private function pullFiles(): int
    {
        $cloud = $this->cloud();
        $this->ensureSyncTables($cloud);
        $base = $this->uploadsPath();
        $count = 0;
        foreach ($cloud->table('sync_files')->select('path, size, modified_at')->get()->getResultArray() as $row) {
            $target = $base . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $row['path']);
            if (strpos(realpath(dirname($target)) ?: dirname($target), $base) !== 0) {
                continue;
            }
            if (is_file($target) && filesize($target) === (int) $row['size'] && filemtime($target) === (int) $row['modified_at']) {
                continue;
            }
            $content = $cloud->table('sync_files')->select('content')->where('path', $row['path'])->get()->getRow()->content;
            if (!is_dir(dirname($target))) {
                mkdir(dirname($target), 0750, true);
            }
            file_put_contents($target, $content);
            touch($target, (int) $row['modified_at']);
            $count++;
        }

        return $count;
    }
}
