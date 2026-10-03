# Prevents duplicate attribute links with the same definition_id and item_id.
# This accounts for dropdown rows (null item_id) and rows associated with sales or receivings.

ALTER TABLE `drawnonward_attribute_links`
    ADD COLUMN `generated_unique_column` VARCHAR(255) GENERATED ALWAYS AS (
        CASE
            WHEN `sale_id` IS NULL AND `receiving_id` IS NULL AND `item_id` IS NOT NULL THEN CONCAT(`definition_id`, '-', `item_id`)
            ELSE NULL
        END
        ) STORED,
    ADD UNIQUE INDEX `attribute_links_uq3` (`generated_unique_column`);

ALTER TABLE `drawnonward_attribute_links` ADD CONSTRAINT `drawnonward_attribute_links_ibfk_1` FOREIGN KEY (`definition_id`) REFERENCES `drawnonward_attribute_definitions` (`definition_id`) ON DELETE RESTRICT;
ALTER TABLE `drawnonward_attribute_links` ADD CONSTRAINT `drawnonward_attribute_links_ibfk_2` FOREIGN KEY (`attribute_id`) REFERENCES `drawnonward_attribute_values` (`attribute_id`) ON DELETE RESTRICT;
