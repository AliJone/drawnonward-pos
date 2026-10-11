<?php

namespace Config;

use CodeIgniter\Config\BaseConfig;

/**
 * Multi-site operation. Values come from .env (sync.mode, sync.siteName, ...), see .env.example.
 */
class Sync extends BaseConfig
{
    /**
     * standalone : single install, no shared database (default)
     * online     : this install works directly on the shared database (database.default points at it)
     * offline    : this install works on its local database and syncs snapshots to database.cloud
     */
    public string $mode = 'standalone';

    /**
     * Name shown to other sites while this install holds the data, e.g. "Shop till". Empty = host name.
     */
    public string $siteName = '';

    /**
     * Minutes without activity after which a logged-in user is logged out.
     */
    public int $idleMinutes = 30;

    /**
     * Minutes without a heartbeat after which an offline-mode lock counts as stale and can be taken over.
     */
    public int $lockTimeoutMinutes = 30;
}
