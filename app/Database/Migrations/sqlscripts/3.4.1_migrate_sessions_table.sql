DROP TABLE IF EXISTS `drawnonward_sessions`;
CREATE TABLE IF NOT EXISTS `drawnonward_sessions` (
    `id` varchar(128) NOT null,
    `ip_address` varchar(45) NOT null,
    `timestamp` timestamp DEFAULT CURRENT_TIMESTAMP NOT null,
    `data` blob NOT null,
    KEY `drawnonward_sessions_timestamp` (`timestamp`)
);

ALTER TABLE drawnonward_sessions ADD PRIMARY KEY (id, ip_address);
