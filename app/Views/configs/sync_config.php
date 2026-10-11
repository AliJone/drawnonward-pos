<?php
/**
 * @var array $sync_status
 * @var array $sync_log
 * @var bool $is_admin
 */
?>
<br>
<div id="config_wrapper">
    <fieldset>
        <div class="form-group form-group-sm">
            <label class="control-label col-xs-2"><?= lang('Sync.mode') ?></label>
            <div class="col-xs-8 form-control-static"><?= lang('Sync.mode_' . $sync_status['mode']) ?></div>
        </div>

        <?php if ($sync_status['mode'] !== 'standalone') { ?>
            <div class="form-group form-group-sm">
                <label class="control-label col-xs-2"><?= lang('Sync.site') ?></label>
                <div class="col-xs-8 form-control-static"><?= esc($sync_status['site']) ?></div>
            </div>

            <div class="form-group form-group-sm">
                <label class="control-label col-xs-2"><?= lang('Sync.cloud_host') ?></label>
                <div class="col-xs-8 form-control-static">
                    <?= esc(config('Database')->cloud['hostname'] ?: config('Database')->default['hostname']) ?> ·
                    <span id="sync_cloud_state"><?= $sync_status['cloud_reachable'] ? lang('Sync.cloud_reachable') : lang('Sync.cloud_unreachable_short') ?></span>
                    <button type="button" class="btn btn-default btn-xs" id="sync_test_button"><?= lang('Sync.test_connection') ?></button>
                </div>
            </div>

            <div class="form-group form-group-sm">
                <label class="control-label col-xs-2"><?= lang('Sync.status') ?></label>
                <div class="col-xs-8 form-control-static">
                    <?php if ($sync_status['holder'] === null) { ?>
                        <?= lang('Sync.lock_free') ?>
                    <?php } else { ?>
                        <?= lang($sync_status['holder_stale'] ? 'Sync.held_by_stale' : 'Sync.held_by', $sync_status['holder']) ?>
                    <?php } ?>
                    <?php if ($sync_status['cloud_version'] !== null) { ?>
                        · <?= lang('Sync.snapshot_version') ?> <?= (int) $sync_status['cloud_version'] ?>
                        <?php if (!empty($sync_status['cloud_pushed_at'])) { ?>(<?= $sync_status['cloud_pushed_at'] ?>)<?php } ?>
                    <?php } ?>
                </div>
            </div>

            <div class="form-group form-group-sm">
                <div class="col-xs-offset-2 col-xs-8">
                    <?php if ($sync_status['mode'] === 'offline') { ?>
                        <button type="button" class="btn btn-primary btn-sm sync-push"><?= lang('Sync.sync_now') ?></button>
                        <button type="button" class="btn btn-default btn-sm sync-pull"><?= lang('Sync.pull_latest') ?></button>
                    <?php } ?>
                    <?php if ($is_admin) { ?>
                        <button type="button" class="btn btn-warning btn-sm" id="sync_takeover_button"><?= lang('Sync.take_over') ?></button>
                        <?php if ($sync_status['mode'] === 'offline') { ?>
                            <a class="btn btn-default btn-sm" href="<?= site_url('sync/downloadSnapshot') ?>"><?= lang('Sync.download_snapshot') ?></a>
                        <?php } ?>
                    <?php } ?>
                </div>
            </div>

            <div class="form-group form-group-sm">
                <label class="control-label col-xs-2"><?= lang('Sync.history') ?></label>
                <div class="col-xs-8">
                    <table class="table table-condensed table-striped">
                        <?php foreach ($sync_log as $entry) { ?>
                            <tr class="<?= $entry['status'] === 'ok' ? '' : 'danger' ?>">
                                <td><?= \App\Libraries\Sync_lib::display($entry['finished_at']) ?></td>
                                <td><?= esc($entry['action']) ?></td>
                                <td><?= esc($entry['status']) ?></td>
                                <td><?= esc($entry['message']) ?></td>
                            </tr>
                        <?php } ?>
                    </table>
                </div>
            </div>
        <?php } ?>
    </fieldset>
</div>

<script type="text/javascript">
    $(document).ready(function() {
        $('#sync_test_button').click(function() {
            $.get("<?= site_url('sync/testConnection') ?>", function(response) {
                $('#sync_cloud_state').text(response.message);
                $.notify({message: response.message}, {type: response.success ? 'success' : 'danger'});
            }, 'json');
        });

        $('#sync_takeover_button').click(function() {
            if (!confirm("<?= esc(lang('Sync.take_over_confirm'), 'js') ?>")) {
                return;
            }
            $.ajax({
                type: 'POST',
                url: "<?= site_url('sync/takeOver') ?>",
                dataType: 'json',
                success: function(response) {
                    $.notify({message: response.message}, {type: response.success ? 'success' : 'danger'});
                    if (response.success) {
                        setTimeout(function() { window.location.reload(); }, 1500);
                    }
                }
            });
        });
    });
</script>
