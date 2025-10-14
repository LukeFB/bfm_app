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

  const [entries, setEntries] = useState([]);
  const [newTitle, setNewTitle] = useState('');
  const [newDesc, setNewDesc] = useState('');

  const fetchEntries = async () => {
    const res = await fetch(`${API}/entries`, { credentials: 'include' });
    if (res.ok) {
      setEntries(await res.json());
    }
  };

  const addEntry = async () => {
    if (!newTitle.trim() || !newDesc.trim()) return;
    const res = await fetch(`${API}/entries`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ title: newTitle, description: newDesc }),
    });
    if (res.ok) {
      setNewTitle('');
      setNewDesc('');
      fetchEntries();
    }
  };

  // Check session on mount
  React.useEffect(() => {
    fetch(`${API}/auth/me`, { credentials: 'include' })
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
      const res1 = await fetch(`${API}/auth/register/options`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username }),
      });
      if (!res1.ok) throw new Error(await res1.text());
      const opts = await res1.json();
      const attResp = await startRegistration(opts);
      const res2 = await fetch(`${API}/auth/register/verify`, {
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
      const res1 = await fetch(`${API}/auth/options`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username }),
      });
      if (!res1.ok) throw new Error(await res1.text());
      const opts = await res1.json();
      const assertionResp = await startAuthentication(opts);
      const res2 = await fetch(`${API}/auth/verify`, {
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
      fetchEntries();
    } catch (e) {
      setMsg('Authentication failed: ' + e.message);
    }
  };

  // Logout function
  const logout = async () => {
    // Optionally, call a backend endpoint to clear the cookie (recommended for security)
    await fetch(`${API}/auth/logout`, { method: 'POST', credentials: 'include' });
    setLoggedInUser(null);
    setMsg('');
    setUsername('');
  };

  if (loggedInUser) {
    return (
      <div style={{
        minHeight: '100vh',
        background: '#f3f2f1',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }}>
        <div style={{
          display: 'flex',
          gap: 32,
          background: 'none'
        }}>
          {/* List Card */}
          <div style={{
            background: '#fff',
            boxShadow: '8px 8px 0 0 rgba(0,0,0,0.25)',
            padding: '32px 24px',
            minWidth: 340,
            maxWidth: 400,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'stretch'
          }}>
            <div style={{
              display: 'flex',
              justifyContent: 'space-between'
            }}>
              <h2 style={{
                color: BLUE,
                fontWeight: 700,
                fontSize: 22,
                margin: 0,
                marginBottom: 18,
                letterSpacing: '-1px'
              }}>
                Welcome, <b>{loggedInUser}</b>
              </h2>
              <button
                onClick={logout}
                style={{
                  background: ORANGE,
                  color: '#fff',
                  fontWeight: 600,
                  fontSize: 15,
                  border: 'none',
                  padding: '10px 0',
                  boxShadow: '4px 4px 0 0 rgba(0,0,0,0.18)',
                  cursor: 'pointer',
                  marginBottom: 18,
                  marginTop: 0,
                  width: 140,
                  alignSelf: 'flex-end'
                }}>
                Log out
              </button>
            </div>
            <div style={{
              fontWeight: 600,
              color: ORANGE,
              marginBottom: 12,
              fontSize: 17
            }}>
              Knowledgebase Entries
            </div>
            <ul style={{ padding: 0, margin: 0, listStyle: 'none' }}>
              {entries.map(e => (
                <li key={e.id} style={{
                  background: '#f7f7f7',
                  border: `1.5px solid ${BLUE}`,
                  padding: '12px 16px',
                  marginBottom: 10
                }}>
                  <b>{e.title}</b><br />
                  <span style={{ color: '#555', fontSize: 14 }}>{e.description}</span>
                </li>
              ))}
            </ul>
          </div>
          {/* Add Object Card */}
          <div style={{
            background: '#fff',
            boxShadow: '8px 8px 0 0 rgba(0,0,0,0.25)',

            padding: '32px 24px',
            minWidth: 300,
            maxWidth: 320,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'stretch'
          }}>
            <input
              type="text"
              placeholder="Title"
              value={newTitle}
              onChange={e => setNewTitle(e.target.value)}
              style={{
                padding: '12px 10px',
                fontSize: 16,
                border: `1.5px solid ${BLUE}`,
                marginBottom: 16,
                outline: 'none',
                background: '#f7f7f7'
              }}
            />
            <textarea
              placeholder="Description"
              value={newDesc}
              onChange={e => setNewDesc(e.target.value)}
              rows={4}
              style={{
                padding: '12px 10px',
                fontSize: 16,
                border: `1.5px solid ${BLUE}`,
                marginBottom: 24,
                outline: 'none',
                background: '#f7f7f7',
                resize: 'none'
              }}
            />
            <button
              onClick={addEntry}
              disabled={!newTitle.trim() || !newDesc.trim()}
              style={{
                background: ORANGE,
                color: '#fff',
                fontWeight: 600,
                fontSize: 16,
                border: 'none',
                padding: '12px 0',
                boxShadow: '4px 4px 0 0 rgba(0,0,0,0.18)',
                cursor: (!newTitle.trim() || !newDesc.trim()) ? 'not-allowed' : 'pointer',
                opacity: (!newTitle.trim() || !newDesc.trim()) ? 0.7 : 1
              }}>
              Add Entry
            </button>
          </div>
        </div>
      </div >
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