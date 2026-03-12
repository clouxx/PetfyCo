-- Historial médico de mascotas
CREATE TABLE IF NOT EXISTS public.medical_records (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  pet_nombre   text NOT NULL,
  tipo         text NOT NULL,          -- Consulta, Vacuna, Cirugía, Examen, Desparasitación, Otro
  fecha        date NOT NULL DEFAULT CURRENT_DATE,
  veterinario  text,
  clinica      text,
  diagnostico  text,
  tratamiento  text,
  costo        numeric,
  notas        text,
  created_at   timestamptz DEFAULT now()
);

ALTER TABLE public.medical_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own medical records" ON public.medical_records
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
