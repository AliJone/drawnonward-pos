--
-- Add support for office menu group
--

ALTER TABLE `drawnonward_grants`
  ADD COLUMN `menu_group` varchar(32) DEFAULT 'home';

INSERT INTO `drawnonward_modules` (`name_lang_key`, `desc_lang_key`, `sort`, `module_id`) VALUES
('module_office', 'module_office_desc', 1, 'office'),
('module_home', 'module_home_desc', 1, 'home');

INSERT INTO `drawnonward_permissions` (`permission_id`, `module_id`) VALUES
('office', 'office'),
('home', 'home');

INSERT INTO `drawnonward_grants` (`permission_id`, `person_id`, `menu_group`) VALUES
('office', 1, 'home'),
('home', 1, 'office');

UPDATE `drawnonward_grants`
SET menu_group = 'office'
WHERE permission_id in ('config', 'home', 'employees', 'taxes', 'migrate')
AND person_id = 1;

--
-- Add support for Work Orders
--

INSERT INTO `drawnonward_app_config` (`key`, `value`) VALUES
('work_order_enable', '0'),
('work_order_format', 'W%y{WSEQ:6}'),
('last_used_work_order_number', '0');

ALTER TABLE `drawnonward_sales`
  ADD COLUMN `work_order_number` varchar(32) DEFAULT NULL,
  ADD COLUMN `sale_type` tinyint(2) NOT NULL DEFAULT 0;

-- sale_type (0=pos, 1=invoice, 2=work order, 3=quote, 4=return)

UPDATE `drawnonward_sales`
  SET `sale_type` = 0;

UPDATE drawnonward_sales t1
  SET sale_type = 4
WHERE EXISTS (SELECT t2.sale_id FROM drawnonward_sales_items t2 WHERE t1.sale_id = t2.sale_id AND t2.quantity_purchased < 0);

UPDATE `drawnonward_sales`
  SET `sale_type` = 3
WHERE `quote_number` IS NOT NULL;

-- The following is needed only if quotes were being treated as work orders.
-- UPDATE `drawnonward_sales`
--   SET `sale_type` = 2, `work_order_number` = `quote_number`
-- WHERE quote_number IS NOT NULL;

-- Identify invoices
UPDATE `drawnonward_sales`
  SET `sale_type` = 1
WHERE `invoice_number` IS NOT NULL;


--  Add permissions for deleting sales and default grant for employee id 1

INSERT INTO `drawnonward_permissions` (`permission_id`, `module_id`) VALUES
('sales_delete', 'sales');

INSERT INTO `drawnonward_grants` (`permission_id`, `person_id`, `menu_group`) VALUES
('sales_delete', 1, '--');


-- Add columns to save per-user language selection

ALTER TABLE `drawnonward_employees`
  ADD COLUMN `language` VARCHAR(48) DEFAULT NULL,
  ADD COLUMN `language_code` VARCHAR(8) DEFAULT NULL;


-- Add support for custom search suggestion format

INSERT INTO `drawnonward_app_config` (`key`, `value`) VALUES
('suggestions_first_column', 'name'),
('suggestions_second_column', ''),
('suggestions_third_column', '');


-- Add key->value to save setting for allowing duplicate barcodes

INSERT INTO `drawnonward_app_config` (`key`, `value`) VALUES
('allow_duplicate_barcodes', '0');


-- Modify items table to allow duplicate barcodes

ALTER TABLE `drawnonward_items`
  DROP INDEX `item_number`,
  ADD KEY `item_number` (item_number);


-- Remove Migrate module as auto migration is supported

DELETE FROM `drawnonward_modules` WHERE `drawnonward_modules`.`module_id` = 'migrate';
DELETE FROM `drawnonward_permissions` WHERE `drawnonward_permissions`.`permission_id` = 'migrate';
DELETE FROM `drawnonward_grants` WHERE `drawnonward_grants`.`permission_id` = 'migrate' AND `drawnonward_grants`.`person_id` = 1;


-- Move Office Module to Right side of Modules list

UPDATE `drawnonward_modules`
SET `sort` = 999
WHERE `name_lang_key` = 'module_office';

UPDATE `drawnonward_modules`
SET `sort` = 98
WHERE `name_lang_key` = 'module_messages';


--
-- Add support for expenses tracking
--

INSERT INTO `drawnonward_modules` (`name_lang_key`, `desc_lang_key`, `sort`, `module_id`) VALUES
('module_expenses', 'module_expenses_desc', 108, 'expenses'),
('module_expenses_categories', 'module_expenses_categories_desc', 109, 'expenses_categories');

INSERT INTO `drawnonward_permissions` (`permission_id`, `module_id`) VALUES
('expenses_categories', 'expenses_categories'),
('expenses', 'expenses'),
('reports_expenses_categories', 'reports');

INSERT INTO `drawnonward_grants` (`permission_id`, `person_id`) VALUES
('expenses', 1),
('expenses_categories', 1),
('reports_expenses_categories', 1);


-- Table structure for table `drawnonward_expense_categories`

CREATE TABLE IF NOT EXISTS `drawnonward_expense_categories` (
  `expense_category_id` int(10) NOT NULL,
  `category_name` varchar(255) DEFAULT NULL,
  `category_description` varchar(255) NOT NULL,
  `deleted` int(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;


-- Table structure for table `drawnonward_expenses`

CREATE TABLE IF NOT EXISTS `drawnonward_expenses` (
  `expense_id` int(10) NOT NULL,
  `date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `amount` decimal(15,2) NOT NULL,
  `payment_type` varchar(40) NOT NULL,
  `expense_category_id` int(11) NOT NULL,
  `description` varchar(255) NOT NULL,
  `employee_id` int(10) NOT NULL,
  `deleted` int(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;


-- Indexes for table `drawnonward_expense_categories`

ALTER TABLE `drawnonward_expense_categories`
  ADD PRIMARY KEY (`expense_category_id`),
  ADD UNIQUE KEY `category_name` (`category_name`);


-- Indexes for table `drawnonward_expenses`

ALTER TABLE `drawnonward_expenses`
  ADD PRIMARY KEY (`expense_id`),
  ADD KEY `expense_category_id` (`expense_category_id`),
  ADD KEY `employee_id` (`employee_id`);


-- AUTO_INCREMENT for table `drawnonward_expense_categories`

ALTER TABLE `drawnonward_expense_categories`
  MODIFY `expense_category_id` int(10) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;


-- AUTO_INCREMENT for table `drawnonward_expenses`

ALTER TABLE `drawnonward_expenses`
  MODIFY `expense_id` int(10) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;


-- Constraints for table `drawnonward_expenses`

ALTER TABLE `drawnonward_expenses`
  ADD CONSTRAINT `drawnonward_expenses_ibfk_1` FOREIGN KEY (`expense_category_id`) REFERENCES `drawnonward_expense_categories` (`expense_category_id`),
  ADD CONSTRAINT `drawnonward_expenses_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `drawnonward_employees` (`person_id`);


-- Add extra columns to `drawnonward_expenses`

ALTER TABLE `drawnonward_expenses`
  ADD COLUMN `supplier_name` varchar(255) DEFAULT NULL,
  ADD COLUMN `supplier_tax_code` varchar(255) DEFAULT NULL,
  ADD COLUMN `tax_amount` decimal(15,2) DEFAULT NULL;


-- Remove unused barcode quality

DELETE FROM `drawnonward_app_config` WHERE `key` = 'barcode_quality';


-- Add new config option to allow derive sale quantity feature

INSERT INTO `drawnonward_app_config` (`key`, `value`) VALUES
('derive_sale_quantity', '0');


-- Add new config option to set print and email receipt behaviour

INSERT INTO `drawnonward_app_config` (`key`, `value`) VALUES
('email_receipt_check_behaviour', 'last'),
('print_receipt_check_behaviour', 'last');


-- This is to provide distinct default comments for both quotes and invoices

INSERT INTO `drawnonward_app_config` (`key`, `value`) VALUES
('quote_default_comments', 'This is a default quote comment');
