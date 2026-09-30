import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import SectionCard from '../components/SectionCard';
import { getFeedback } from '../services/api';

function stars(rating) {
  const value = Math.max(0, Math.min(5, rating || 0));
  return `${'★'.repeat(value)}${'☆'.repeat(5 - value)}`;
}

export default function RatingsOverviewPage() {
  const [feedback, setFeedback] = useState([]);
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

  const average = ratings.length
    ? (ratings.reduce((sum, item) => sum + (item.rating || 0), 0) / ratings.length).toFixed(1)
    : null;

  const withComment = ratings.filter((item) => (item.message || '').trim()).length;

  const distribution = useMemo(() => {
    const buckets = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
    ratings.forEach((item) => {
      if (buckets[item.rating] !== undefined) buckets[item.rating] += 1;
    });
    return buckets;
  }, [ratings]);

  const max = Math.max(...Object.values(distribution), 1);

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <p className="eyebrow">IT</p>
          <h2>App Rating Review</h2>
        </div>
        <Link className="primary-link-button" to="/ratings/stream">
          View ratings stream →
        </Link>
      </div>

      {error ? <p className="error-banner">{error}</p> : null}

      <SectionCard title="Summary" subtitle="Star ratings from the “Rate the app” screen.">
        <div className="coverage-grid">
          <div className="coverage-card">
            <strong>
              {average ?? '—'}
              {average ? ' / 5' : ''}
            </strong>
            <span>Average rating</span>
          </div>
          <div className="coverage-card">
            <strong>{ratings.length}</strong>
            <span>Total ratings</span>
          </div>
          <div className="coverage-card">
            <strong>{withComment}</strong>
            <span>Left a comment</span>
          </div>
        </div>
      </SectionCard>

      <SectionCard title="How many gave each score" subtitle="">
        <div className="rating-bars">
          {[5, 4, 3, 2, 1].map((score) => (
            <div className="rating-bar-row" key={score}>
              <span className="rating-bar-label">{stars(score)}</span>
              <div className="rating-bar-track">
                <div
                  className="rating-bar-fill"
                  style={{ width: `${(distribution[score] / max) * 100}%` }}
                />
              </div>
              <span className="rating-bar-count">{distribution[score]}</span>
            </div>
          ))}
        </div>
      </SectionCard>
    </div>
  );
}
