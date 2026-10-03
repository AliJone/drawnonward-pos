-- Migration to make tax_category_id nullable in drawnonward_items
ALTER TABLE drawnonward_items
    MODIFY COLUMN tax_category_id INT NULL;
