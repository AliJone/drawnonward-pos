ALTER TABLE `drawnonward_attribute_links`
DROP FOREIGN KEY `drawnonward_attribute_links_ibfk_4`;

ALTER TABLE `drawnonward_attribute_links`
ADD CONSTRAINT `drawnonward_attribute_links_ibfk_4`
FOREIGN KEY (`receiving_id`) REFERENCES `drawnonward_receivings`(`receiving_id`)
ON DELETE CASCADE
ON UPDATE RESTRICT;
