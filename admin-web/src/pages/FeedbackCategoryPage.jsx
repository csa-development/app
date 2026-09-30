import { useEffect, useMemo, useState } from 'react';
import SectionCard from '../components/SectionCard';
import FeedbackRow, { FEEDBACK_STATUS_OPTIONS } from '../components/FeedbackRow';
import { getFeedback, updateFeedback } from '../services/api';

// One shared page, parameterised by category — same pattern as
// ContentListPage's configKey. Renders just the feedback of one
// category (bug reports, suggestions, questions, or compliments),
// each getting its own sidebar sub-page instead of one long combined
// list with a category dropdown to dig through.
export default function FeedbackCategoryPage({ category, title, subtitle, emptyLabel }) {
  const [feedback, setFeedback] = useState([]);
  const [filter, setFilter] = useState('ALL');
  const [error, setError] = useState('');

  useEffect(() => {
    getFeedback()
      .then(setFeedback)
      .catch((err) => setError(err.message));
  }, []);

  const items = useMemo(
    () => feedback.filter((item) => item.category === category),
    [feedback, category]
  );

  const visible = useMemo(
    () =>
      items
        .filter((item) => filter === 'ALL' || item.status === filter)
        .sort((a, b) => new Date(b.created_at) - new Date(a.created_at)),
    [items, filter]
  );

  async function apply(id, payload) {
    try {
      const updated = await updateFeedback(id, payload);
      setFeedback(updated);
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <p className="eyebrow">IT</p>
          <h2>{title}</h2>
        </div>
      </div>

      {error ? <p className="error-banner">{error}</p> : null}

      <SectionCard
        title={title}
        subtitle={subtitle}
        action={
          <label className="fb-filter">
            Show
            <select value={filter} onChange={(e) => setFilter(e.target.value)}>
              <option value="ALL">All statuses</option>
              {FEEDBACK_STATUS_OPTIONS.map((s) => (
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
            <FeedbackRow
              key={item.id}
              item={item}
              showCategory={false}
              onChangeStatus={(id, status) => apply(id, { status })}
              onSaveNote={(id, admin_notes) => apply(id, { admin_notes })}
            />
          ))}
          {!visible.length ? (
            <div className="empty-state">
              <strong>Nothing here</strong>
              <span>{emptyLabel}</span>
            </div>
          ) : null}
        </div>
      </SectionCard>
    </div>
  );
}
