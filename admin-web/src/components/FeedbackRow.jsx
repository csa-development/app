import { useState } from 'react';

export const FEEDBACK_STATUS_OPTIONS = [
  { value: 'NEW', label: 'New' },
  { value: 'IN_REVIEW', label: 'In review' },
  { value: 'RESOLVED', label: 'Resolved' },
  { value: 'ARCHIVED', label: 'Archived' }
];

// Shared by every feedback category page (bugs, suggestions, questions,
// compliments) and the ratings stream — one row layout for a single
// piece of user feedback, with its status control and an optional
// internal (staff-only) note.
export default function FeedbackRow({ item, showCategory = true, onChangeStatus, onSaveNote }) {
  const [noteOpen, setNoteOpen] = useState(false);
  const [draft, setDraft] = useState(item.admin_notes || '');

  return (
    <article className="fb-row">
      <div className="fb-row-head">
        {showCategory ? <span className="fb-cat">{item.category_display}</span> : null}
        <span className="fb-from">
          From {item.user?.name || 'Anonymous'}
          {item.user?.email ? ` (${item.user.email})` : ''} · {new Date(item.created_at).toLocaleDateString()}
        </span>
      </div>

      <p className="fb-body">{item.message?.trim() || 'No message left.'}</p>

      <div className="fb-row-foot">
        <label className="fb-status">
          Status
          <select value={item.status} onChange={(e) => onChangeStatus(item.id, e.target.value)}>
            {FEEDBACK_STATUS_OPTIONS.map((s) => (
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
