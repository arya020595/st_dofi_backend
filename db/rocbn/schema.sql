-- Structure of the external ROCBN company registry table, as read from the real server with
-- DESCRIBE / SHOW CREATE TABLE / SHOW INDEX on 2026-10-23 (tdd_db.sync_rocbn_hotel, MySQL 8.0).
--
-- The registry is owned and populated by another system; production is never created or altered from
-- here. This file is only loaded into the Docker MySQL stand-in (local, staging) and the CI/test database:
--   * docker-compose*.yml mounts it into the mysql image's init directory (first start of an empty volume);
--   * Rocbn::Seeding::Schema loads it (CREATE TABLE IF NOT EXISTS, so re-running is a no-op).
-- Keep it identical to the real table: AUTO_INCREMENT=<n> is dropped, and IF NOT EXISTS is added.
CREATE TABLE IF NOT EXISTS `sync_rocbn_hotel` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `registration_no` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address_1` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address_2` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address_3` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mukim` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `village` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `district` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `postal_code` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `country` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contact` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `telp` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fax` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `entity_id` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `incorporation_date` date DEFAULT NULL,
  `nature_of_business` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `business_sector_code` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `role` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `type_of_role` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `identity_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `identity_number` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `nationality` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `person_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `position` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `gender` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `appointment_date` date DEFAULT NULL,
  `old_value` json DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `sync_rocbn_hotel_registration_no_index` (`registration_no`),
  KEY `sync_rocbn_hotel_name_index` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
