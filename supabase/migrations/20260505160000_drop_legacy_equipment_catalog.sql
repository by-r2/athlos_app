-- Mobile app v30+ no longer syncs equipment from Supabase (`CatalogSyncService` only
-- exercises + exercise_target_muscles). These tables remain from seed
-- `20260226000000_create_catalog.sql` and can be dropped if no other backend/consumer reads them.

DROP TABLE IF EXISTS exercise_equipments CASCADE;
DROP TABLE IF EXISTS equipments CASCADE;
