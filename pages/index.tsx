
import { useState } from 'react'
import { supabase } from '../supabaseClient'

export default function Home() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [message, setMessage] = useState<string | null>(null)

  const login = async () => {
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    setMessage(error ? 'Error: ' + error.message : 'Ok!')
  }

  return (
    <main style={{ padding: 24 }}>
      <h1>PetfyCo Web — Login</h1>
      <input placeholder="Email" onChange={(e)=>setEmail(e.target.value)} /><br/>
      <input placeholder="Password" type="password" onChange={(e)=>setPassword(e.target.value)} /><br/>
      <button onClick={login}>Entrar</button>
      <p>{message}</p>
      <a href="/publish">Publicar mascota</a>
    </main>
  )
}
