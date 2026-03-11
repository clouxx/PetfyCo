-- Migration: Add 'delivery_addresses' JSONB column to profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS delivery_addresses jsonb DEFAULT '[]';
