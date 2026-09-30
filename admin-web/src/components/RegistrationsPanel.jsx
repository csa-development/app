import { useEffect, useState } from 'react';
import SectionCard from './SectionCard';

// Registrations table + receptionist check-in for one event or campaign.
// `id` is the event/campaign id; `fetchRegistrations` and `checkIn` are
// the matching API functions.
export default function RegistrationsPanel({ id, fetchRegistrations, checkIn }) {
  const [registrations, setRegistrations] = useState([]);
  const [error, setError] = useState('');

  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [okMsg, setOkMsg] = useState('');
  const [errMsg, setErrMsg] = useState('');

  useEffect(() => {
    let active = true;
    fetchRegistrations(id)
      .then((data) => active && setRegistrations(data))
      .catch((err) => active && setError(err.message));
    return () => {
      active = false;
    };
  }, [id, fetchRegistrations]);

  async function handleCheckIn(e) {
    e.preventDefault();
    setOkMsg('');
    setErrMsg('');

    const value = code.trim();
    if (!value) {
      setErrMsg('Enter a check-in code.');
      return;
    }

    setBusy(true);
    try {
      const result = await checkIn(id, value);
      const updated = result.item;
      setRegistrations((current) =>
        current.map((item) => (item.id === updated.id ? updated : item))
      );

      if (result.already_checked_in) {
        const time = new Date(updated.checked_in_at).toLocaleTimeString();
        setErrMsg(`${updated.user.name} was already checked in at ${time}.`);
      } else {
        setOkMsg(`${updated.user.name} checked in successfully.`);
      }
      setCode('');
    } catch (err) {
      setErrMsg(err.message);
    } finally {
      setBusy(false);
    }
  }

  const checkedIn = registrations.filter((item) => item.checked_in).length;

  return (
    <SectionCard
      title={`Registrations (${registrations.length})`}
      subtitle={`${checkedIn} checked in. People who registered through the app.`}
    >
      {error ? <p className="error-text">{error}</p> : null}

      <form className="form" onSubmit={handleCheckIn} style={{ marginBottom: '20px' }}>
        <div className="form-grid">
          <label>
            Check-in code
            <input
              value={code}
              onChange={(e) => setCode(e.target.value)}
              placeholder="e.g. CSA-4829"
            />
          </label>
        </div>
        <div className="button-row">
          <button type="submit" disabled={busy}>
            {busy ? 'Checking in…' : 'Check in'}
          </button>
        </div>
        {okMsg ? <p className="success-text">{okMsg}</p> : null}
        {errMsg ? <p className="error-text">{errMsg}</p> : null}
      </form>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Phone</th>
              <th>National ID</th>
              <th>Check-in Code</th>
              <th>Status</th>
              <th>Registered</th>
            </tr>
          </thead>
          <tbody>
            {registrations.map((item) => (
              <tr key={item.id}>
                <td>{item.user.name}</td>
                <td>{item.user.email}</td>
                <td>{item.user.phone || 'N/A'}</td>
                <td>{item.user.national_id || 'N/A'}</td>
                <td>{item.check_in_code}</td>
                <td>
                  {item.checked_in ? (
                    <span className="pill pill-success">
                      Checked in {new Date(item.checked_in_at).toLocaleTimeString()}
                    </span>
                  ) : (
                    <span className="pill">Not checked in</span>
                  )}
                </td>
                <td>{new Date(item.registered_at).toLocaleString()}</td>
              </tr>
            ))}
            {!registrations.length ? (
              <tr>
                <td colSpan="7" className="muted-text">
                  No registrations yet.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
    </SectionCard>
  );
}
