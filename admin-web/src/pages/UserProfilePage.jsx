import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import SectionCard from '../components/SectionCard';
import useConfirm from '../hooks/useConfirm';
import { getUserDetail, updateUser } from '../services/api';

const emptyEdit = {
  first_name: '',
  last_name: '',
  email: '',
  phone: '',
  national_id: '',
  is_staff: false,
  is_active: true
};

function toEdit(detail) {
  return {
    first_name: detail.profile.first_name || '',
    last_name: detail.profile.last_name || '',
    email: detail.email || '',
    phone: detail.profile.phone || '',
    national_id: detail.profile.national_id || '',
    is_staff: detail.is_staff,
    is_active: detail.is_active ?? true
  };
}

export default function UserProfilePage() {
  const { id } = useParams();
  const navigate = useNavigate();

  const [user, setUser] = useState(null);
  const [form, setForm] = useState(emptyEdit);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [confirm, confirmDialog] = useConfirm();

  useEffect(() => {
    setLoading(true);
    setMessage('');
    getUserDetail(id)
      .then((detail) => {
        setUser(detail);
        setForm(toEdit(detail));
      })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [id]);

  function setField(name, value) {
    setForm((current) => ({ ...current, [name]: value }));
  }

  async function saveChanges(event) {
    event.preventDefault();
    if (!user) return;

    const disabling = user.is_active && !form.is_active;
    const ok = await confirm({
      title: disabling ? `Disable ${user.name}'s account?` : `Save changes to ${user.name}?`,
      message: disabling
        ? 'They will be signed out of the mobile app and unable to log back in until re-enabled.'
        : 'Updates the account details on file.',
      confirmLabel: 'Save changes'
    });
    if (!ok) return;

    try {
      const updated = await updateUser(user.id, form);
      setUser(updated);
      setForm(toEdit(updated));
      setMessage('User details updated successfully.');
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div className="page">
      {confirmDialog}
      <div className="page-header">
        <div>
          <Link className="back-link" to="/users">
            ← Back to user activity
          </Link>
          <h2>{user ? user.name : 'User profile'}</h2>
        </div>
      </div>

      {error ? <p className="error-banner">{error}</p> : null}

      {loading ? (
        <p className="muted-text">Loading…</p>
      ) : !user ? (
        <p className="muted-text">This user could not be found.</p>
      ) : (
        <>
          <div className="coverage-grid">
            <div className="coverage-card">
              <strong>{user.username}</strong>
              <span>Username</span>
            </div>
            <div className="coverage-card">
              <strong>{user.is_active ? 'Active' : 'Disabled'}</strong>
              <span>Account status</span>
            </div>
            <div className="coverage-card">
              <strong>{user.is_staff ? 'Admin' : 'Citizen'}</strong>
              <span>Role</span>
            </div>
            <div className="coverage-card">
              <strong>{new Date(user.date_joined).toLocaleDateString()}</strong>
              <span>Joined</span>
            </div>
          </div>

          <SectionCard title="Account details" subtitle="Editable admin controls for this account.">
            <form className="form" onSubmit={saveChanges}>
              <div className="form-grid">
                <label>
                  First name
                  <input
                    value={form.first_name}
                    onChange={(e) => setField('first_name', e.target.value)}
                  />
                </label>
                <label>
                  Last name
                  <input
                    value={form.last_name}
                    onChange={(e) => setField('last_name', e.target.value)}
                  />
                </label>
              </div>
              <div className="form-grid">
                <label>
                  Email
                  <input value={form.email} onChange={(e) => setField('email', e.target.value)} />
                </label>
                <label>
                  Phone
                  <input value={form.phone} onChange={(e) => setField('phone', e.target.value)} />
                </label>
              </div>
              <label>
                National ID
                <input
                  value={form.national_id}
                  onChange={(e) => setField('national_id', e.target.value)}
                />
              </label>
              <div className="form-grid">
                <label className="checkbox">
                  <input
                    type="checkbox"
                    checked={form.is_active}
                    onChange={(e) => setField('is_active', e.target.checked)}
                  />
                  <span>Account active</span>
                </label>
              </div>
              <div className="button-row">
                <button type="submit">Save user changes</button>
                <button
                  type="button"
                  className="secondary-button"
                  onClick={() => navigate('/users')}
                >
                  Cancel
                </button>
              </div>
              {message ? <p className="success-text">{message}</p> : null}
            </form>
          </SectionCard>

          <div className="coverage-grid">
            <div className="coverage-card">
              <strong>{user.device_tokens.length}</strong>
              <span>Device tokens</span>
            </div>
            <div className="coverage-card">
              <strong>{user.incident_summaries.length}</strong>
              <span>Recent incidents</span>
            </div>
            <div className="coverage-card">
              <strong>{user.recent_feedback.length}</strong>
              <span>Recent feedback</span>
            </div>
            <div className="coverage-card">
              <strong>{user.recent_logins.length}</strong>
              <span>Tracked logins</span>
            </div>
            <div className="coverage-card">
              <strong>{user.verification_history.length}</strong>
              <span>OTP history</span>
            </div>
          </div>

          <SectionCard title="Recent logins" subtitle="">
            <div className="list compact-list">
              {user.recent_logins.map((item) => (
                <article key={item.id} className="list-item">
                  <div>
                    <h3>{item.source}</h3>
                    <p>
                      {item.identifier || 'No identifier recorded'}
                      {item.ip_address ? ` • ${item.ip_address}` : ''}
                    </p>
                  </div>
                  <span className="pill">{new Date(item.created_at).toLocaleString()}</span>
                </article>
              ))}
              {!user.recent_logins.length ? (
                <p className="muted-text">No tracked logins.</p>
              ) : null}
            </div>
          </SectionCard>

          <SectionCard title="Recent feedback" subtitle="">
            <div className="list compact-list">
              {user.recent_feedback.map((item) => (
                <article key={item.id} className="list-item">
                  <div>
                    <h3>{item.category_display}</h3>
                    <p>{item.message}</p>
                  </div>
                  <span className="pill">{new Date(item.created_at).toLocaleDateString()}</span>
                </article>
              ))}
              {!user.recent_feedback.length ? (
                <p className="muted-text">No feedback from this user.</p>
              ) : null}
            </div>
          </SectionCard>
        </>
      )}
    </div>
  );
}
