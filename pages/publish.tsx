
import { useEffect, useState } from 'react'
import { supabase } from '../supabaseClient'

export default function Publish() {
  const [nombre, setNombre] = useState('')
  const [especie, setEspecie] = useState<'perro'|'gato'>('gato')
  const [status, setStatus] = useState('publicado')
  const [msg, setMsg] = useState<string>('')

  useEffect(()=>{
    supabase.auth.getUser().then(({data})=>{
      if (!data.user) setMsg('Inicia sesión en /')
    })
  }, [])

  const publicar = async () => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { setMsg('Inicia sesión'); return }
    const { error } = await supabase.from('pets').insert({ owner_id: user.id, nombre, especie, estado: status })
    setMsg(error ? 'Error: '+error.message : 'Publicado!')
  }

  return (
    <main style={{ padding: 24 }}>
      <h1>Publicar mascota (Web)</h1>
      <label>Nombre</label><br/>
      <input value={nombre} onChange={(e)=>setNombre(e.target.value)} /><br/>
      <label>Especie</label><br/>
      <select value={especie} onChange={(e)=>setEspecie(e.target.value as any)}>
        <option value="perro">Perro</option>
        <option value="gato">Gato</option>
      </select><br/>
      <button onClick={publicar}>Publicar</button>
      <p>{msg}</p>
      <a href="/">Volver</a>
    </main>
  )
}
