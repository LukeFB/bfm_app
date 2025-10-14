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

  // Registration
  const register = async () => {
    setMsg('');
    try {
      // 1. Get registration options from backend
      const res1 = await fetch(`${API}/register/options`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username }),
      });
      if (!res1.ok) throw new Error(await res1.text());
      const opts = await res1.json();

      // 2. Start registration ceremony
      const attResp = await startRegistration(opts);

      // 3. Send attestation response to backend for verification
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
      // 1. Get authentication options from backend
      const res1 = await fetch(`${API}/authenticate/options`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username }),
      });
      if (!res1.ok) throw new Error(await res1.text());
      const opts = await res1.json();

      // 2. Start authentication ceremony
      const assertionResp = await startAuthentication(opts);

      // 3. Send assertion response to backend for verification
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
    } catch (e) {
      setMsg('Authentication failed: ' + e.message);
    }
  };

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
        maxWidth: 360,
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
          marginBottom: 36,
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
            marginBottom: 12,
            outline: 'none'
          }}
        />
        <button style={{
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
          marginBottom: 8,
          cursor: 'pointer'
        }}>
          Or
        </div>
                <button style={{
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