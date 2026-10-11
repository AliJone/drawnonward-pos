<?php
/**
 * @var array $config
 */
?>

<script type="text/javascript">
    // Live clock
    const clock_tick = function clock_tick() {
        setInterval('update_clock();', 1000);
    }

    // Start the clock immediately
    clock_tick();

    const update_clock = function update_clock() {
        document.getElementById('liveclock').innerHTML = moment().format("<?= dateformat_momentjs($config['dateformat'] . ' ' . $config['timeformat']) ?>");
    }

    const notify = $.notify;

    $.notify = function(content, options) {
        const message = typeof content === "object" ? content.message : content;
        const sanitizedMessage = DOMPurify.sanitize(message, { ALLOWED_TAGS: [], ALLOWED_ATTR: [] });
        return notify(sanitizedMessage, options);
    };

    $.notifyDefaults({
        placement: {
            align: "<?= esc($config['notify_horizontal_position'], 'js') ?>",
            from: "<?= esc($config['notify_vertical_position'], 'js') ?>"
        }
    });

    const csrf_token = function() {
        return "<?= esc(csrf_hash(), 'js') ?>";
    };

    const csrf_form_base = function() {
        return {
            <?= esc(config('Security')->tokenName, 'js') ?>: function() {
                return csrf_token()
            }
        }
    };

    const setup_csrf_token = function() {
        $('input[name="<?= esc(config('Security')->tokenName, 'js') ?>"]').val(csrf_token());
    };

    const ajax = $.ajax;

    $.ajax = function() {
        let args = arguments[0];
        if (args['type'] && args['type'].toLowerCase() == 'post' && csrf_token()) {
            if (typeof args['data'] === 'string') {
                args['data'] += '&' + $.param(csrf_form_base());
            } else {
                args['data'] = $.extend(args['data'], csrf_form_base());
            }
        }

        return ajax.apply(this, arguments);
    };

    $(document).ajaxComplete(setup_csrf_token);
    $(document).ready(function() {
        $("#logout").click(function(event) {
            event.preventDefault();
            $.ajax({
                url: "<?= site_url('home/logout'); ?>",
                data: {
                    "<?= esc(config('Security')->tokenName, 'js'); ?>": csrf_token()
                },
                success: function() {
                    window.location.href = '<?= site_url(); ?>';
                },
                method: "POST"
            });
        });
    });

    // Automatic logout after a period without activity; the server enforces the same limit
    const idle_logout_ms = <?= (int) config('Sync')->idleMinutes ?> * 60 * 1000;
    let idle_timer;
    const reset_idle_timer = function() {
        clearTimeout(idle_timer);
        idle_timer = setTimeout(function() {
            window.location.href = "<?= site_url('home/logout') ?>";
        }, idle_logout_ms);
    };
    ['click', 'keydown', 'mousemove', 'scroll', 'touchstart'].forEach(function(name) {
        document.addEventListener(name, reset_idle_timer, {passive: true});
    });
    reset_idle_timer();

    <?php if (($sync_status['mode'] ?? 'standalone') !== 'standalone') { ?>
        const sync_action = function(url, confirmation) {
            if (confirmation && !confirm(confirmation)) {
                return;
            }
            $.ajax({
                type: 'POST',
                url: url,
                dataType: 'json',
                success: function(response) {
                    $.notify({message: response.message}, {type: response.success ? 'success' : 'danger'});
                    if (response.success) {
                        setTimeout(function() { window.location.reload(); }, 1500);
                    }
                },
                error: function() {
                    $.notify({message: "<?= esc(lang('Sync.cloud_unreachable_short'), 'js') ?>"}, {type: 'danger'});
                }
            });
        };

        $(document).ready(function() {
            $('#sync_push_button, .sync-push').click(function() {
                sync_action("<?= site_url('sync/push') ?>", null);
            });
            $('#sync_pull_button, .sync-pull').click(function() {
                sync_action("<?= site_url('sync/pull') ?>", "<?= esc(lang('Sync.pull_confirm'), 'js') ?>");
            });
        });

        // Keeps the offline-mode lock alive while the page is open
        setInterval(function() {
            $.ajax({
                type: 'POST',
                url: "<?= site_url('sync/heartbeat') ?>",
                dataType: 'json',
                success: function(status) {
                    if (status.lock === false) {
                        $.notify({message: "<?= esc(lang('Sync.lock_lost'), 'js') ?>"}, {type: 'danger'});
                    }
                },
                error: function(xhr) {
                    if (xhr.status === 401 || xhr.status === 403) {
                        window.location.reload();
                    }
                }
            });
        }, 60000);
    <?php } ?>

    const submit = $.fn.submit;

    $.fn.submit = function() {
        setup_csrf_token();
        submit.apply(this, arguments);
    };
</script>
