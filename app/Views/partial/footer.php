            </div>
        </div>

        <div id="footer">
            <div class="jumbotron push-spaces">
                <strong>
                    <?= esc(DISTRIBUTOR_NOTICE) ?> ·
                    <a href="tel:<?= esc(DISTRIBUTOR_PHONE, 'attr') ?>"><?= esc(DISTRIBUTOR_PHONE) ?></a> ·
                    <a href="mailto:<?= esc(DISTRIBUTOR_EMAIL, 'attr') ?>"><?= esc(DISTRIBUTOR_EMAIL) ?></a> ·
                    <?= esc(config('App')->application_version) ?>
                </strong>
            </div>
        </div>
    </body>
</html>
