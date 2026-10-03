INSERT INTO drawnonward_stock_locations (location_name) (SELECT DISTINCT(location) FROM drawnonward_items WHERE NOT EXISTS (select location from drawnonward_stock_locations where location_name = location));
INSERT INTO drawnonward_item_quantities (item_id, location_id, quantity) (SELECT item_id, location_id, quantity FROM drawnonward_items, drawnonward_stock_locations where drawnonward_items.location = drawnonward_stock_locations.location_name);
ALTER TABLE drawnonward_items DROP COLUMN location;
