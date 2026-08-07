-- Migration: Add 'group_dissolved' value to notification_type enum
ALTER TYPE public.notification_type ADD VALUE IF NOT EXISTS 'group_dissolved';
