import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import ListToolbar from '../components/ListToolbar';
import SectionCard from '../components/SectionCard';
import { getUsers } from '../services/api';

const RECENT_MS = 7 * 24 * 60 * 60 * 1000;

const FILTER_LABELS = {
  active: 'Active accounts',
  disabled: 'Disabled accounts',
  recent: 'Signed up in the last 7 days'
};

export default function UsersPage() {
  const navigate = useNavigate();
  const [users, setUsers] = useState([]);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [searchParams, setSearchParams] = useSearchParams();

  const activeFilter =
    searchParams.get('joined') === 'recent'
      ? 'recent'
      : ['active', 'disabled'].includes(searchParams.get('status'))
      ? searchParams.get('status')
      : null;

  function clearFilter() {
    setSearchParams({}, { replace: true });
  }

  useEffect(() => {
    getUsers().then(setUsers).catch((err) => setError(err.message));
  }, []);

  const filteredUsers = useMemo(() => {
    const query = search.trim().toLowerCase();
    return users.filter((user) => {
      const matchesSearch =
        !query ||
        [user.name, user.email].some((value) =>
          String(value || '').toLowerCase().includes(query)
        );
      if (!matchesSearch) return false;
      if (activeFilter === 'active') return user.is_active;
      if (activeFilter === 'disabled') return !user.is_active;
      if (activeFilter === 'recent') {
        return user.date_joined && Date.now() - new Date(user.date_joined).getTime() < RECENT_MS;
      }
      return true;
    });
  }, [users, search, activeFilter]);

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <p className="eyebrow">IT</p>
          <h2>User Activity</h2>
        </div>
      </div>

      {error ? <p className="error-banner">{error}</p> : null}

      <SectionCard
        title="Users"
        subtitle="Every citizen account and its last tracked login. Click a user to open their profile."
      >
        <ListToolbar
          searchValue={search}
          onSearchChange={setSearch}
          searchPlaceholder="Search users by name or email"
          resultLabel={`${filteredUsers.length} user(s)`}
        />

        {activeFilter ? (
          <div className="filter-chips">
            <button type="button" className="filter-chip" onClick={clearFilter}>
              {FILTER_LABELS[activeFilter]} <span aria-hidden="true">✕</span>
            </button>
          </div>
        ) : null}

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Email</th>
                <th>Role</th>
                <th>Status</th>
                <th>Last login</th>
                <th>Source</th>
              </tr>
            </thead>
            <tbody>
              {filteredUsers.map((user) => (
                <tr
                  key={user.id}
                  className="clickable-row"
                  onClick={() => navigate(`/users/${user.id}`)}
                >
                  <td>{user.name}</td>
                  <td>{user.email}</td>
                  <td>{user.is_staff ? 'Admin' : 'Citizen'}</td>
                  <td>
                    <span className={`pill ${user.is_active ? 'pill-success' : 'pill-danger'}`}>
                      {user.is_active ? 'Active' : 'Disabled'}
                    </span>
                  </td>
                  <td>
                    {user.last_login_at
                      ? new Date(user.last_login_at).toLocaleString()
                      : 'Never tracked'}
                  </td>
                  <td>{user.last_login_source || 'Unknown'}</td>
                </tr>
              ))}
              {!filteredUsers.length ? (
                <tr>
                  <td colSpan="6" className="muted-text">
                    No users match this view.
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </SectionCard>
    </div>
  );
}
