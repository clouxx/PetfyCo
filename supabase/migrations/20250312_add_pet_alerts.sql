-- Tabla de alertas de mascotas perdidas
CREATE TABLE IF NOT EXISTS public.pet_alerts (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  especie text,
  talla text,
  depto text,
  municipio text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.pet_alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own alerts" ON public.pet_alerts
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
