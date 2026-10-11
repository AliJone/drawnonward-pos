<?php

namespace App\Database\Migrations;

use App\Libraries\Sync_lib;
use CodeIgniter\Database\Migration;

class SyncTables extends Migration
{
    /**
     * Bookkeeping tables for multi-site operation (lock, log, uploaded files in transit).
     */
    public function up(): void
    {
        (new Sync_lib())->ensureSyncTables($this->db);
    }

    public function down(): void
    {
        $this->forge->dropTable('sync_files', true);
        $this->forge->dropTable('sync_log', true);
        $this->forge->dropTable('sync_state', true);
    }
}
