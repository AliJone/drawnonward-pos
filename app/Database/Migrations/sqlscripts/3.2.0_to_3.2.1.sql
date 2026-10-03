--
-- Add support for GDPR utility
--

-- Add columns to customer table for tracking purposes and explicit consent of data registration

ALTER TABLE `drawnonward_customers`
  ADD COLUMN `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN `employee_id` int(10) NOT NULL,
  ADD COLUMN `consent` int(1) NOT NULL DEFAULT '0';

-- This is to enforce privacy by means of scrambling customer details

INSERT INTO `drawnonward_app_config` (`key`, `value`) VALUES
('enforce_privacy', '0');


-- Add print receipt autoreturn delay

INSERT INTO `drawnonward_app_config` (`key`, `value`) VALUES
('print_delay_autoreturn', '0');


-- Insure that the receiving quantity is not zero

UPDATE drawnonward_receivings_items SET receiving_quantity = 1 WHERE receiving_quantity = 0;
