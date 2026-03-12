-- Tabla de recetas / prescripciones médicas de mascotas
CREATE TABLE IF NOT EXISTS public.prescriptions (
  id             uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id        uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  pet_nombre     text NOT NULL,
  medicamento    text NOT NULL,
  dosis          text NOT NULL,
  frecuencia     text NOT NULL,          -- ej. "Cada 8 horas"
  hora_recordatorio text,               -- ej. "08:00"
  recordatorio   boolean DEFAULT false,
  fecha_inicio   date NOT NULL DEFAULT CURRENT_DATE,
  fecha_fin      date,
  notas          text,
  activa         boolean DEFAULT true,
  created_at     timestamptz DEFAULT now()
);

ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own prescriptions" ON public.prescriptions
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
