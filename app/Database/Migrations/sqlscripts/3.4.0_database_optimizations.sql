#drawnonward_attribute_values table
ALTER TABLE `drawnonward_attribute_values` ADD UNIQUE(`attribute_date`);
ALTER TABLE `drawnonward_attribute_values` ADD UNIQUE(`attribute_decimal`);

#opsos_attribute_definitions table
ALTER TABLE `drawnonward_attribute_definitions` MODIFY `definition_flags` tinyint(1) NOT NULL;
ALTER TABLE `drawnonward_attribute_definitions` ADD INDEX(`definition_name`);
ALTER TABLE `drawnonward_attribute_definitions` ADD INDEX(`definition_type`);

#drawnonward_cash_up table
ALTER TABLE `drawnonward_cash_up` MODIFY `deleted` tinyint(1) DEFAULT 0 NOT NULL;

#drawnonward_customers table
ALTER TABLE `drawnonward_customers` MODIFY `taxable` tinyint(1) DEFAULT 1 NOT NULL;
ALTER TABLE `drawnonward_customers` MODIFY `deleted` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_customers` MODIFY `discount_type` tinyint(1) DEFAULT 0 NOT NULL;

ALTER TABLE `drawnonward_customers` ADD CONSTRAINT `drawnonward_customers_ibfk_1` FOREIGN KEY (`person_id`) REFERENCES `drawnonward_people`(`person_id`);
ALTER TABLE `drawnonward_customers_points` ADD CONSTRAINT `drawnonward_customers_points_ibfk_1` FOREIGN KEY (`person_id`) REFERENCES `drawnonward_customers` (`person_id`);
ALTER TABLE `drawnonward_sales` ADD CONSTRAINT `drawnonward_sales_ibfk_2` FOREIGN KEY (`customer_id`) REFERENCES `drawnonward_customers` (`person_id`);

#drawnonward_customers_packages table
ALTER TABLE `drawnonward_customers_packages` MODIFY `deleted` tinyint(1) DEFAULT 0 NOT NULL;

#drawnonward_dinner_tables table
ALTER TABLE `drawnonward_dinner_tables` MODIFY `deleted` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_dinner_tables` ADD INDEX(`status`);

#drawnonward_employees table
ALTER TABLE `drawnonward_employees` MODIFY `deleted` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_employees` MODIFY `hash_version` tinyint(1) DEFAULT 2 NOT NULL;

ALTER TABLE `drawnonward_sales_payments` ADD CONSTRAINT `drawnonward_sales_payments_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `drawnonward_employees` (`person_id`);
ALTER TABLE `drawnonward_sales` ADD CONSTRAINT `drawnonward_sales_ibfk_1` FOREIGN KEY (`employee_id`) REFERENCES `drawnonward_employees` (`person_id`);
ALTER TABLE `drawnonward_receivings` ADD CONSTRAINT `drawnonward_receivings_ibfk_1` FOREIGN KEY (`employee_id`) REFERENCES `drawnonward_employees` (`person_id`);
ALTER TABLE `drawnonward_inventory` ADD CONSTRAINT `drawnonward_inventory_ibfk_2` FOREIGN KEY (`trans_user`) REFERENCES `drawnonward_employees` (`person_id`);
ALTER TABLE `drawnonward_grants` ADD CONSTRAINT `drawnonward_grants_ibfk_2` foreign key (`person_id`) references `drawnonward_employees` (`person_id`) ON DELETE CASCADE;
ALTER TABLE `drawnonward_expenses` ADD CONSTRAINT `drawnonward_expenses_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `drawnonward_employees` (`person_id`);
ALTER TABLE `drawnonward_employees` ADD CONSTRAINT `drawnonward_employees_ibfk_1` FOREIGN KEY (`person_id`) REFERENCES `drawnonward_people` (`person_id`);
ALTER TABLE `drawnonward_cash_up` ADD CONSTRAINT `drawnonward_cash_up_ibfk_1` FOREIGN KEY (`open_employee_id`) REFERENCES `drawnonward_employees` (`person_id`);
ALTER TABLE `drawnonward_cash_up` ADD CONSTRAINT `drawnonward_cash_up_ibfk_2` FOREIGN KEY (`close_employee_id`) REFERENCES `drawnonward_employees` (`person_id`);

#drawnonward_expenses table
ALTER TABLE `drawnonward_expenses` MODIFY `deleted` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_expenses` ADD INDEX(`payment_type`);
ALTER TABLE `drawnonward_expenses` ADD INDEX(`amount`);

#drawnonward_expenses_categories table
ALTER TABLE `drawnonward_expense_categories` MODIFY `deleted` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_expense_categories` ADD INDEX(`category_description`);

#drawnonward_giftcards table
ALTER TABLE `drawnonward_giftcards` MODIFY `deleted` tinyint(1) DEFAULT 0 NOT NULL;

#drawnonward_items table
ALTER TABLE `drawnonward_items` MODIFY `deleted` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_items` MODIFY `stock_type` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_items` MODIFY `item_type` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_items` ADD INDEX(`deleted`, `item_type`);
ALTER TABLE `drawnonward_items` ADD INDEX (`item_id`,`deleted`);
ALTER TABLE `drawnonward_items` ADD UNIQUE INDEX `items_uq1` (`supplier_id`, `item_id`, `deleted`, `item_type`);

#drawnonward_item_kits table
ALTER TABLE `drawnonward_item_kits` MODIFY `kit_discount_type` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_item_kits` MODIFY `price_option` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_item_kits` MODIFY `print_option` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_item_kits` ADD INDEX(`name`,`description`);

#drawnonward_people table
ALTER TABLE `drawnonward_people` ADD INDEX(`first_name`, `last_name`, `email`, `phone_number`);

#drawnonward_receivings_items
ALTER TABLE `drawnonward_receivings_items` MODIFY `discount_type` tinyint(1) DEFAULT 0 NOT NULL;

#drawnonward_sales
ALTER TABLE `drawnonward_sales` MODIFY `sale_status` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_sales` MODIFY `sale_type` tinyint(1) DEFAULT 0 NOT NULL;

#drawnonward_sales_items
ALTER TABLE `drawnonward_sales_items` MODIFY `discount_type` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_sales_items` MODIFY `print_option` tinyint(1) DEFAULT 0 NOT NULL;

#drawnonward_sales_items_taxes
ALTER TABLE `drawnonward_sales_items_taxes` MODIFY `tax_type` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_sales_items_taxes` MODIFY `rounding_code` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_sales_items_taxes` MODIFY `cascade_sequence` tinyint(1) DEFAULT 0 NOT NULL;

#drawnonward_sales_taxes
ALTER TABLE `drawnonward_sales_taxes` MODIFY `print_sequence` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_sales_taxes` MODIFY `rounding_code` tinyint(1) DEFAULT 0 NOT NULL;

#drawnonward_sessions table
ALTER TABLE `drawnonward_sessions` ADD INDEX(`id`);
ALTER TABLE `drawnonward_sessions` ADD INDEX(`ip_address`);

#drawnonward_stock_locations table
ALTER TABLE `drawnonward_stock_locations` MODIFY `deleted` tinyint(1) DEFAULT 0 NOT NULL;

#drawnonward_suppliers table
ALTER TABLE `drawnonward_suppliers` MODIFY `deleted` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_suppliers` MODIFY `category` tinyint(1) NOT NULL;
ALTER TABLE `drawnonward_suppliers` ADD INDEX(`category`);
ALTER TABLE `drawnonward_suppliers` ADD INDEX(`company_name`, `deleted`);

ALTER TABLE `drawnonward_expenses` ADD CONSTRAINT `drawnonward_expenses_ibfk_3` FOREIGN KEY (`supplier_id`) REFERENCES `drawnonward_suppliers` (`person_id`);
ALTER TABLE `drawnonward_items` ADD CONSTRAINT `drawnonward_items_ibfk_1` FOREIGN KEY (`supplier_id`) REFERENCES `drawnonward_suppliers` (`person_id`);
ALTER TABLE `drawnonward_receivings` ADD CONSTRAINT `drawnonward_receivings_ibfk_2` FOREIGN KEY (`supplier_id`) REFERENCES `drawnonward_suppliers` (`person_id`);
ALTER TABLE `drawnonward_suppliers` ADD CONSTRAINT `drawnonward_suppliers_ibfk_1` FOREIGN KEY (`person_id`) REFERENCES `drawnonward_people` (`person_id`);

#drawnonward_tax_categories table
ALTER TABLE `drawnonward_tax_categories` MODIFY `deleted` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_tax_categories` MODIFY `tax_group_sequence` tinyint(1) NOT NULL;

#drawnonward_tax_jurisdictions table
ALTER TABLE `drawnonward_tax_jurisdictions` MODIFY `deleted` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_tax_jurisdictions` MODIFY `tax_group_sequence` tinyint(1) DEFAULT 0 NOT NULL;
ALTER TABLE `drawnonward_tax_jurisdictions` MODIFY `cascade_sequence` tinyint(1) DEFAULT 0 NOT NULL;

#drawnonward_tax_rates table
ALTER TABLE `drawnonward_tax_rates` MODIFY `tax_rounding_code` tinyint(1) DEFAULT 0 NOT NULL;
