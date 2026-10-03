import { useState } from 'react';

export default function LoginPage({ onLogin, loading, error }) {
  const [form, setForm] = useState({
    identifier: '',
    password: ''
  });

  function handleChange(event) {
    const { name, value } = event.target;
    setForm((current) => ({ ...current, [name]: value }));
  }

  function handleSubmit(event) {
    event.preventDefault();
    onLogin(form);
  }

  return (
    <div className="login-shell">
      <section className="login-card">
        <div className="login-head">
          <img src="/csalogo.png" alt="CSA logo" className="login-logo" />
          <p className="eyebrow">CSA Mobile</p>
          <h1>Admin Console Login</h1>
        </div>
        <form className="form" onSubmit={handleSubmit} autoComplete="off">
          <label>
            Username or email
            <input
              name="identifier"
              value={form.identifier}
              onChange={handleChange}
              autoComplete="off"
              required
            />
          </label>

          <label>
            Password
            <input
              name="password"
              type="password"
              value={form.password}
              onChange={handleChange}
              autoComplete="new-password"
              required
            />
          </label>

          <button type="submit" disabled={loading}>
            {loading ? 'Signing in...' : 'Sign in'}
          </button>
          {error ? <p className="error-text">{error}</p> : null}
        </form>
      </section>
    </div>
  );
}
