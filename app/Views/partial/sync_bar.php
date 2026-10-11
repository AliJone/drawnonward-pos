<?php
/**
 * Multi-site status in the top bar. Rendered from local state; the heartbeat refreshes it.
 *
 * @var array $sync_status
 */
if ($sync_status['mode'] === 'standalone') {
    return;
}
?>
<div id="sync_bar" class="navbar-left" style="margin-left: 16px;" data-mode="<?= esc($sync_status['mode'], 'attr') ?>">
    <span id="sync_status_text">
        <?php if ($sync_status['mode'] === 'online') { ?>
            <?= lang('Sync.mode_online') ?>
        <?php } elseif ($sync_status['working_offline']) { ?>
            <?= lang('Sync.working_offline') ?>
        <?php } elseif ($sync_status['holds_lock']) { ?>
            <?= lang('Sync.holding_since', [$sync_status['held_since']]) ?> ·
            <?= $sync_status['last_sync'] !== '' ? lang('Sync.last_sync', [$sync_status['last_sync']]) : lang('Sync.never_synced') ?>
        <?php } else { ?>
            <?= lang('Sync.mode_offline') ?>
        <?php } ?>
    </span>
    <?php if ($sync_status['mode'] === 'offline') { ?>
        <button type="button" class="btn btn-xs btn-primary" id="sync_push_button" style="margin-left: 8px;<?= $sync_status['holds_lock'] ? '' : ' display: none;' ?>">
            <span class="glyphicon glyphicon-cloud-upload"></span> <?= lang('Sync.sync_now') ?>
        </button>
        <button type="button" class="btn btn-xs btn-default" id="sync_pull_button" style="margin-left: 8px;<?= $sync_status['holds_lock'] ? ' display: none;' : '' ?>">
            <span class="glyphicon glyphicon-cloud-download"></span> <?= lang('Sync.pull_latest') ?>
        </button>
    <?php } ?>
</div>
