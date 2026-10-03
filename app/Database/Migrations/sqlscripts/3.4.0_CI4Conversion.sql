
DROP TABLE `drawnonward_sessions`;

CREATE TABLE IF NOT EXISTS `drawnonward_sessions` (
    `id` varchar(128) NOT NULL,
    `ip_address` varchar(45) NOT NULL,
    `timestamp` timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    `data` blob NOT NULL,
    KEY `drawnonward_sessions_timestamp` (`timestamp`)
    );

ALTER TABLE drawnonward_sessions ADD PRIMARY KEY (id, ip_address);

UPDATE `drawnonward_app_config`
SET `value` = REPLACE(value, '|', ',')
WHERE `key` = 'image_allowed_types';

-- due to language rename, reset to english
UPDATE `drawnonward_app_config` SET `value` = 'en' WHERE `key` = 'language_code' ;
UPDATE `drawnonward_app_config` SET `value` = 'english' WHERE `key` = 'language' ;
