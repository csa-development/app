import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import SectionCard from '../components/SectionCard';
import { getFeedback, updateFeedback } from '../services/api';

const STATUS_OPTIONS = [
  { value: 'NEW', label: 'New' },
  { value: 'IN_REVIEW', label: 'In review' },
  { value: 'RESOLVED', label: 'Resolved' },
  { value: 'ARCHIVED', label: 'Archived' }
];

function stars(rating) {
  const value = Math.max(0, Math.min(5, rating || 0));
  return `${'★'.repeat(value)}${'☆'.repeat(5 - value)}`;
}

function RatingRow({ item, onChangeStatus, onSaveNote }) {
  const [noteOpen, setNoteOpen] = useState(false);
  const [draft, setDraft] = useState(item.admin_notes || '');

  return (
    <article className="fb-row">
      <div className="fb-row-head">
        <span className="fb-cat" aria-label={`${item.rating || 0} out of 5`}>
          {stars(item.rating)}
        </span>
        <span className="fb-from">
          From {item.user?.name || 'Anonymous'}
          {item.user?.email ? ` (${item.user.email})` : ''} ·{' '}
          {new Date(item.created_at).toLocaleDateString()}
        </span>
      </div>

      <p className="fb-body">{item.message?.trim() || 'No comment left.'}</p>

      <div className="fb-row-foot">
        <label className="fb-status">
          Status
          <select value={item.status} onChange={(e) => onChangeStatus(item.id, e.target.value)}>
            {STATUS_OPTIONS.map((s) => (
              <option key={s.value} value={s.value}>
                {s.label}
              </option>
            ))}
          </select>
        </label>

        {!noteOpen ? (
          <button
            type="button"
            className="secondary-button btn-sm"
            onClick={() => {
              setDraft(item.admin_notes || '');
              setNoteOpen(true);
            }}
          >
            {item.admin_notes ? 'Edit internal note' : 'Add an internal note'}
          </button>
        ) : null}
      </div>

      {item.admin_notes && !noteOpen ? (
        <p className="fb-saved-note">
          <span className="fb-note-label">Internal note</span>
          {item.admin_notes}
        </p>
      ) : null}

      {noteOpen ? (
        <div className="fb-note-box">
          <label>
            Internal note (only staff see this)
            <textarea
              rows="2"
              autoFocus
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
            />
          </label>
          <div className="button-row">
            <button
              type="button"
              className="btn-sm"
              onClick={() => {
                onSaveNote(item.id, draft.trim());
                setNoteOpen(false);
              }}
            >
              Save note
            </button>
            <button
              type="button"
              className="secondary-button btn-sm"
              onClick={() => setNoteOpen(false)}
            >
              Cancel
            </button>
          </div>
        </div>
      ) : null}
    </article>
  );
}

export default function RatingsStreamPage() {
  const [feedback, setFeedback] = useState([]);
  const [filter, setFilter] = useState('ALL');
  const [error, setError] = useState('');

  useEffect(() => {
    getFeedback()
      .then(setFeedback)
      .catch((err) => setError(err.message));
  }, []);

  const ratings = useMemo(
    () => feedback.filter((item) => item.category === 'APP_RATING'),
    [feedback]
  );

  const visible = useMemo(
    () =>
      ratings
        .filter((item) => filter === 'ALL' || item.status === filter)
        .sort((a, b) => new Date(b.created_at) - new Date(a.created_at)),
    [ratings, filter]
  );

  async function apply(id, payload) {
    try {
      const items = await updateFeedback(id, payload);
      setFeedback(items);
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <Link className="back-link" to="/ratings">
            ← Back to app rating review
          </Link>
          <h2>Ratings Stream</h2>
        </div>
      </div>

      {error ? <p className="error-banner">{error}</p> : null}

      <SectionCard
        title="Individual ratings"
        subtitle="Every star rating left in the app. Set each one's status as you handle it."
        action={
          <label className="fb-filter">
            Show
            <select value={filter} onChange={(e) => setFilter(e.target.value)}>
              <option value="ALL">All ratings</option>
              {STATUS_OPTIONS.map((s) => (
                <option key={s.value} value={s.value}>
                  {s.label}
                </option>
              ))}
            </select>
          </label>
        }
      >
        <p className="fb-count">{visible.length} shown</p>

        <div className="fb-rows">
          {visible.map((item) => (
            <RatingRow
              key={item.id}
              item={item}
              onChangeStatus={(id, status) => apply(id, { status })}
              onSaveNote={(id, admin_notes) => apply(id, { admin_notes })}
            />
          ))}
          {!visible.length ? (
            <div className="empty-state">
              <strong>No ratings here</strong>
              <span>Nothing matches the current filter.</span>
            </div>
          ) : null}
        </div>
      </SectionCard>
    </div>
  );
}
