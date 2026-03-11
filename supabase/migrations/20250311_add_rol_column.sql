-- Migration: Add 'rol' column to profiles table
-- Run this once in Supabase SQL Editor: Project → SQL Editor → New query

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS rol text DEFAULT 'buscador'
  CHECK (rol IN ('buscador', 'publicador'));

-- Set default for any existing rows that have NULL
UPDATE public.profiles SET rol = 'buscador' WHERE rol IS NULL;
