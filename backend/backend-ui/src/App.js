// App.js
import React, { useState } from 'react';
import {
  startRegistration,
  startAuthentication,
} from '@simplewebauthn/browser';

const ORANGE = '#ff6934';
const BLUE = '#005494';

const API = 'http://localhost:8000';

function App() {
  const [username, setUsername] = useState('');
  const [msg, setMsg] = useState('');
  const [loggedInUser, setLoggedInUser] = useState(null);

  // Check session on mount
  React.useEffect(() => {
    fetch(`${API}/me`, { credentials: 'include' })
      .then(res => {
        if (!res.ok) return null;
        return res.json();
      })
      .then(data => {
        if (data && data.username) setLoggedInUser(data.username);
        // else do nothing, user is not logged in
      })
      .catch(() => {
        // Optionally handle fetch/network errors here
      });
  }, []);

  // Registration
  const register = async () => {
    setMsg('');
    try {
      const res1 = await fetch(`${API}/register/options`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username }),
      });
      if (!res1.ok) throw new Error(await res1.text());
      const opts = await res1.json();
      const attResp = await startRegistration(opts);
      const res2 = await fetch(`${API}/register/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username,
          credential: attResp,
        }),
      });
      if (!res2.ok) throw new Error(await res2.text());
      setMsg('Registration successful!');
    } catch (e) {
      setMsg('Registration failed: ' + e.message);
    }
  };

  // Authentication
  const login = async () => {
    setMsg('');
    try {
      const res1 = await fetch(`${API}/authenticate/options`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username }),
      });
      if (!res1.ok) throw new Error(await res1.text());
      const opts = await res1.json();
      const assertionResp = await startAuthentication(opts);
      const res2 = await fetch(`${API}/authenticate/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username,
          credential: JSON.stringify(assertionResp),
        }),
      });
      if (!res2.ok) throw new Error(await res2.text());
      setMsg('Authentication successful!');
      setLoggedInUser(username);
    } catch (e) {
      setMsg('Authentication failed: ' + e.message);
    }
  };

  if (loggedInUser) {
    return (
      <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22 }}>
        Welcome, <b>{loggedInUser}</b>!<br />
        <span style={{ fontSize: 16, color: '#888' }}>You are logged in.</span>
      </div>
    );
  }

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center'
    }}>

      {/* Card */}
      <div style={{
        background: '#fff',
        boxShadow: '8px 8px 0 0 rgba(0,0,0,0.25)', // hard shadow down/right
        padding: '40px 32px 32px 32px',
        minWidth: 340,
        maxWidth: 340,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'stretch'
      }}>

        {/* Logo */}
        <img
          src="bfm.jpg"
          alt="Bay Financial Mentors"
          style={{ width: 320, marginBottom: 32 }}
        />

        <h2 style={{
          color: BLUE,
          fontWeight: 700,
          fontSize: 28,
          margin: 0,
          marginBottom: 12,
          letterSpacing: '-1px'
        }}>
          Moni Knowledgebase
        </h2>
        <input
          type="text"
          placeholder="Username"
          value={username}
          onChange={e => setUsername(e.target.value)}
          style={{
            padding: '12px 10px',
            fontSize: 16,
            border: `1.5px solid ${BLUE}`,
            marginBottom: 8,
            outline: 'none'
          }}
        />
                <div style={{
          color: '#000000',
          fontSize: 14,
          textAlign: 'center',
          marginTop: 8,
          marginBottom: 36,
        }}>
          {msg}
        </div>
        <button
          onClick={login}
          style={{
            background: ORANGE,
            color: '#fff',
            fontWeight: 600,
            fontSize: 16,
            border: 'none',
            padding: '12px 0',
            boxShadow: '4px 4px 0 0 rgba(0,0,0,0.18)',
            cursor: 'pointer',
            marginBottom: 8
          }}>
          Sign in with Passkey
        </button>
        <div style={{
          color: '#000000',
          fontSize: 14,
          textAlign: 'center',
          marginTop: 8,
          marginBottom: 16,
        }}>
          Or
        </div>
        <button
          onClick={register}

          style={{
            background: BLUE,
            color: '#fff',
            fontWeight: 600,
            fontSize: 16,
            border: 'none',
            padding: '12px 0',
            boxShadow: '4px 4px 0 0 rgba(0,0,0,0.18)',
            cursor: 'pointer',
            marginBottom: 8
          }}>
          Register
        </button>
      </div>
    </div>
  );
}

export default App;