import { useEffect, useMemo, useState } from 'react';
import ListToolbar from '../components/ListToolbar';
import SectionCard from '../components/SectionCard';
import useConfirm from '../hooks/useConfirm';
import { createStaff, getStaff, updateStaff } from '../services/api';

const ROLE_OPTIONS = ['SUPERADMIN', 'CERT', 'IT', 'LECO', 'COMMS'];

const emptyForm = {
  id: null,
  first_name: '',
  last_name: '',
  email: '',
  password: '',
  roles: [],
  is_active: true
};

export default function StaffPage() {
  const [staff, setStaff] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [confirm, confirmDialog] = useConfirm();

  useEffect(() => {
    getStaff().then(setStaff).catch((err) => setError(err.message));
  }, []);

  const filteredStaff = useMemo(() => {
    const query = search.trim().toLowerCase();
    if (!query) return staff;
    return staff.filter((member) =>
      [member.name, member.email, ...(member.roles || [])].some((value) =>
        String(value || '').toLowerCase().includes(query)
      )
    );
  }, [staff, search]);

  function toggleRole(role) {
    setForm((current) => ({
      ...current,
      roles: current.roles.includes(role)
        ? current.roles.filter((item) => item !== role)
        : [...current.roles, role]
    }));
  }

  function startEdit(member) {
    setForm({
      id: member.id,
      first_name: '',
      last_name: '',
      email: member.email,
      password: '',
      roles: member.roles,
      is_active: member.is_active
    });
    setMessage('');
    setError('');
  }

  async function handleSubmit(event) {
    event.preventDefault();

    const deactivating = form.id && !form.is_active;
    const ok = await confirm({
      title: form.id
        ? deactivating
          ? `Disable ${form.email}?`
          : `Update access for ${form.email}?`
        : `Create a staff account for ${form.email}?`,
      message: form.id
        ? deactivating
          ? 'They will be signed out and blocked from the admin console until re-enabled.'
          : `Roles: ${form.roles.join(', ') || 'none'}.`
        : `They will be able to sign in with roles: ${form.roles.join(', ') || 'none'}.`,
      confirmLabel: form.id ? 'Save' : 'Create account'
    });
    if (!ok) return;

    setMessage('');
    setError('');

    try {
      if (form.id) {
        const updated = await updateStaff(form.id, {
          roles: form.roles,
          is_active: form.is_active
        });
        setStaff((current) =>
          current.map((item) => (item.id === updated.id ? updated : item))
        );
        setMessage('Staff account updated successfully.');
      } else {
        const created = await createStaff({
          first_name: form.first_name,
          last_name: form.last_name,
          email: form.email,
          password: form.password,
          roles: form.roles
        });
        setStaff((current) => [created, ...current]);
        setMessage('Staff account created successfully.');
      }
      setForm(emptyForm);
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div className="page two-column-grid">
      {confirmDialog}
      <SectionCard
        title={form.id ? 'Edit staff roles' : 'Add staff account'}
        subtitle="Assign one or more roles. SUPERADMIN grants full access to every domain."
      >
        <form className="form" onSubmit={handleSubmit}>
          {!form.id ? (
            <>
              <div className="form-grid">
                <label>
                  First name
                  <input
                    value={form.first_name}
                    onChange={(e) => setForm((c) => ({ ...c, first_name: e.target.value }))}
                  />
                </label>
                <label>
                  Last name
                  <input
                    value={form.last_name}
                    onChange={(e) => setForm((c) => ({ ...c, last_name: e.target.value }))}
                  />
                </label>
              </div>
              <label>
                Email
                <input
                  type="email"
                  value={form.email}
                  onChange={(e) => setForm((c) => ({ ...c, email: e.target.value }))}
                  required
                />
              </label>
              <label>
                Password
                <input
                  type="password"
                  value={form.password}
                  onChange={(e) => setForm((c) => ({ ...c, password: e.target.value }))}
                  required
                />
              </label>
            </>
          ) : (
            <p className="muted-text">Editing roles for {form.email}.</p>
          )}

          <label>Roles</label>
          <div className="role-checkbox-grid">
            {ROLE_OPTIONS.map((role) => (
              <label key={role} className="checkbox">
                <input
                  type="checkbox"
                  checked={form.roles.includes(role)}
                  onChange={() => toggleRole(role)}
                />
                <span>{role}</span>
              </label>
            ))}
          </div>

          {form.id ? (
            <label className="checkbox">
              <input
                type="checkbox"
                checked={form.is_active}
                onChange={(e) => setForm((c) => ({ ...c, is_active: e.target.checked }))}
              />
              <span>Account active</span>
            </label>
          ) : null}

          <div className="button-row">
            <button type="submit">{form.id ? 'Save roles' : 'Create staff account'}</button>
            {form.id ? (
              <button type="button" className="secondary-button" onClick={() => setForm(emptyForm)}>
                Cancel edit
              </button>
            ) : null}
          </div>
          {message ? <p className="success-text">{message}</p> : null}
          {error ? <p className="error-text">{error}</p> : null}
        </form>
      </SectionCard>

      <SectionCard title="Staff accounts" subtitle="Everyone with access to this admin console.">
        <ListToolbar
          searchValue={search}
          onSearchChange={setSearch}
          searchPlaceholder="Search staff by name, email or role"
          resultLabel={`${filteredStaff.length} account(s)`}
        />
        <div className="list">
          {filteredStaff.map((member) => (
            <article key={member.id} className="list-item">
              <div>
                <h3>{member.name}</h3>
                <p>{member.email}</p>
                <div className="pill-row" style={{ marginTop: '0.5rem' }}>
                  {member.roles.map((role) => (
                    <span key={role} className="pill">
                      {role}
                    </span>
                  ))}
                  {!member.roles.length ? <span className="muted-pill pill">No role assigned</span> : null}
                </div>
              </div>
              <div className="stacked-meta">
                <span className="pill">{member.is_active ? 'Active' : 'Disabled'}</span>
                <button type="button" className="secondary-button" onClick={() => startEdit(member)}>
                  Edit roles
                </button>
              </div>
            </article>
          ))}
        </div>
      </SectionCard>
    </div>
  );
}
