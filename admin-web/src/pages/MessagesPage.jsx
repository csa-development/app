import { useEffect, useMemo, useState } from 'react';
import ListToolbar from '../components/ListToolbar';
import SectionCard from '../components/SectionCard';
import { getContactMessages, updateContactMessage } from '../services/api';

const inboxStatuses = ['NEW', 'IN_REVIEW', 'RESOLVED', 'ARCHIVED'];

export default function MessagesPage() {
  const [messages, setMessages] = useState([]);
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [search, setSearch] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    getContactMessages()
      .then(setMessages)
      .catch((err) => setError(err.message));
  }, []);

  const filtered = useMemo(() => {
    const query = search.trim().toLowerCase();
    return messages.filter((item) => {
      const matchesFilter = statusFilter === 'ALL' || item.status === statusFilter;
      const matchesSearch =
        !query ||
        [item.message, item.name, item.email].some((value) =>
          String(value || '').toLowerCase().includes(query)
        );
      return matchesFilter && matchesSearch;
    });
  }, [messages, statusFilter, search]);

  async function handleUpdate(id, payload) {
    try {
      const items = await updateContactMessage(id, payload);
      setMessages(items);
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div className="page">
      <SectionCard title="Contact messages" subtitle="Messages sent through the app's public contact form.">
        <div className="coverage-grid">
          <div className="coverage-card">
            <strong>{messages.length}</strong>
            <span>Total messages</span>
          </div>
          <div className="coverage-card">
            <strong>{messages.filter((item) => item.status === 'NEW').length}</strong>
            <span>New</span>
          </div>
          <div className="coverage-card">
            <strong>{messages.filter((item) => item.status === 'RESOLVED').length}</strong>
            <span>Resolved</span>
          </div>
        </div>
      </SectionCard>

      <SectionCard
        title="Message stream"
        subtitle="Public messages with their own workflow state and notes."
        action={
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="filter-select"
          >
            <option value="ALL">All</option>
            {inboxStatuses.map((status) => (
              <option key={status} value={status}>
                {status}
              </option>
            ))}
          </select>
        }
      >
        {error ? <p className="error-text">{error}</p> : null}
        <ListToolbar
          searchValue={search}
          onSearchChange={setSearch}
          searchPlaceholder="Search contact messages"
          resultLabel={`${filtered.length} message(s)`}
        />
        <div className="list">
          {filtered.map((item) => (
            <article key={item.id} className="list-item">
              <div className="wide-block">
                <h3>{item.name}</h3>
                <p>{item.message}</p>
                <div className="info-row">
                  <span>{item.email}</span>
                  <span>{item.phone || 'No phone'}</span>
                  <span>{new Date(item.created_at).toLocaleString()}</span>
                </div>
                <textarea
                  rows="2"
                  placeholder="Admin notes"
                  value={item.admin_notes || ''}
                  onChange={(e) =>
                    setMessages((current) =>
                      current.map((entry) =>
                        entry.id === item.id ? { ...entry, admin_notes: e.target.value } : entry
                      )
                    )
                  }
                />
              </div>
              <div className="stacked-meta">
                <span className="pill">{item.status_display}</span>
                <select
                  value={item.status}
                  onChange={(e) => handleUpdate(item.id, { status: e.target.value })}
                >
                  {inboxStatuses.map((status) => (
                    <option key={status} value={status}>
                      {status}
                    </option>
                  ))}
                </select>
                <button
                  type="button"
                  className="secondary-button"
                  onClick={() => handleUpdate(item.id, { admin_notes: item.admin_notes || '' })}
                >
                  Save notes
                </button>
              </div>
            </article>
          ))}
          {!filtered.length ? <p className="muted-text">No messages match this view.</p> : null}
        </div>
      </SectionCard>
    </div>
  );
}
