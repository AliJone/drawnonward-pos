<?php

namespace App\Database\Migrations;

use CodeIgniter\Database\Migration;
use Config\Drawnonward;

class ItemUnits extends Migration
{
    /**
     * Unit of measure per item (pcs, kg, L...) with the list of units in the config, and decimal quantities by default.
     */
    public function up(): void
    {
        if (!$this->db->fieldExists('unit', 'items')) {
            $this->forge->addColumn('items', ['unit' => ['type' => 'VARCHAR', 'constraint' => 16, 'default' => '']]);
        }
        $this->db->table('app_config')->ignore(true)->insert(['key' => 'units', 'value' => "pcs\nkg\ng\nL\nml\nm\nbox\npack\ndozen"]);
        // 0 was the upstream default; an install that chose another precision keeps it
        $this->db->table('app_config')->where('key', 'quantity_decimals')->where('value', '0')->update(['value' => '3']);
        config(Drawnonward::class)->update_settings();    // settings are cached
    }

    public function down(): void
    {
        $this->forge->dropColumn('items', 'unit');
        $this->db->table('app_config')->where('key', 'units')->delete();
        config(Drawnonward::class)->update_settings();
    }
}
