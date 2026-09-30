import { useEffect, useState } from 'react';
import BarChart from '../components/BarChart';
import SectionCard from '../components/SectionCard';
import StatCard from '../components/StatCard';
import { getDashboardSummary } from '../services/api';

export default function DashboardPage() {
  const [summary, setSummary] = useState({
    stats: {},
    charts: {
      logins_per_day: [],
      reports_per_day: [],
      content_mix: []
    },
    recent_activity: []
  });
  const [error, setError] = useState('');

  useEffect(() => {
    getDashboardSummary()
      .then(setSummary)
      .catch((err) => setError(err.message));
  }, []);

  return (
    <div className="page">
      <section className="hero-panel">
        <div>
          <p className="eyebrow">Overview</p>
          <h2>Live backend statistics for the mobile app</h2>
          <p className="hero-copy">
            This workspace tracks publishing, users, and incident activity in one place,
            with the same calm, high-clarity feel as your reference dashboard.
          </p>
        </div>
        <div className="hero-badges">
          <span className="hero-badge">Shared backend</span>
          <span className="hero-badge hero-badge-soft">Realtime admin visibility</span>
        </div>
      </section>

      {error ? <p className="error-banner">{error}</p> : null}

      <div className="stats-grid">
        <StatCard
          label="Registered users"
          value={summary.stats.total_users || 0}
          hint="Accounts stored in Django"
          accent="users"
          icon="U"
        />
        <StatCard
          label="Published alerts"
          value={summary.stats.alerts_count || 0}
          hint="Alerts visible to app users"
          accent="alerts"
          icon="A"
        />
        <StatCard
          label="Breaking stories"
          value={summary.stats.breaking_news_count || 0}
          hint="Urgent news items marked as breaking"
          accent="breaking"
          icon="B"
        />
        <StatCard
          label="Pending reports"
          value={summary.stats.reports_pending || 0}
          hint="Reports still waiting for action"
          accent="reports"
          icon="R"
        />
      </div>

      <div className="two-column-grid">
        <BarChart
          title="Logins per day"
          items={summary.charts.logins_per_day || []}
          tone="blue"
        />
        <BarChart
          title="Reports per day"
          items={summary.charts.reports_per_day || []}
          tone="gold"
        />
      </div>

      <div className="two-column-grid">
        <BarChart
          title="Content mix"
          items={summary.charts.content_mix || []}
          tone="teal"
        />

        <SectionCard
          title="Platform coverage"
          subtitle="The admin console now reaches more of the app surface."
        >
          <div className="coverage-grid">
            <div className="coverage-card">
              <strong>{summary.stats.events_count || 0}</strong>
              <span>Events</span>
            </div>
            <div className="coverage-card">
              <strong>{summary.stats.campaigns_count || 0}</strong>
              <span>Campaigns</span>
            </div>
            <div className="coverage-card">
              <strong>{summary.stats.press_releases_count || 0}</strong>
              <span>Press releases</span>
            </div>
            <div className="coverage-card">
              <strong>{summary.stats.total_feedback || 0}</strong>
              <span>Feedback items</span>
            </div>
            <div className="coverage-card">
              <strong>{summary.stats.contact_messages_total || 0}</strong>
              <span>Contact messages</span>
            </div>
            <div className="coverage-card">
              <strong>{summary.stats.reports_total || 0}</strong>
              <span>Total reports</span>
            </div>
          </div>
        </SectionCard>
      </div>

      <SectionCard
        title="Recent activity"
        subtitle="Latest login events recorded by the backend."
      >
        <div className="list">
          {(summary.recent_activity || []).map((activity) => (
            <article key={activity.id} className="list-item">
              <div>
                <h3>{activity.user}</h3>
                <p>{activity.source}</p>
              </div>
              <span className="pill">
                {new Date(activity.created_at).toLocaleString()}
              </span>
            </article>
          ))}
        </div>
      </SectionCard>
    </div>
  );
}
