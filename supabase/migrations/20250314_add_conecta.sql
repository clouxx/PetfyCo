-- Posts de la comunidad
CREATE TABLE IF NOT EXISTS public.posts (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  content    text NOT NULL,
  image_url  text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read posts" ON public.posts
  FOR SELECT USING (true);

CREATE POLICY "Users manage own posts" ON public.posts
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Likes
CREATE TABLE IF NOT EXISTS public.post_likes (
  post_id uuid REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  PRIMARY KEY (post_id, user_id)
);

ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read likes" ON public.post_likes
  FOR SELECT USING (true);

CREATE POLICY "Users manage own likes" ON public.post_likes
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Comentarios
CREATE TABLE IF NOT EXISTS public.post_comments (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id    uuid REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
  user_id    uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  content    text NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read comments" ON public.post_comments
  FOR SELECT USING (true);

CREATE POLICY "Users manage own comments" ON public.post_comments
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
