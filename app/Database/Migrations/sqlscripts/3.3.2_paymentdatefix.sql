UPDATE `drawnonward_sales_payments`
  JOIN `drawnonward_sales` ON `drawnonward_sales`.`sale_id`=`drawnonward_sales_payments`.`sale_id`
  SET `drawnonward_sales_payments`.`payment_time`=`drawnonward_sales`.`sale_time`;
