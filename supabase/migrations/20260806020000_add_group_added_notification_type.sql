-- Migration: 20260806020000_add_group_added_notification_type.sql
-- Description: Add 'group_added' value to notification_type enum

alter type public.notification_type add value if not exists 'group_added';
