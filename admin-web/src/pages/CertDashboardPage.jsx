import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import BarChart from '../components/BarChart';
import SectionCard from '../components/SectionCard';
import StatCard from '../components/StatCard';
import { createReportStatus, getCertDashboard, getReportStatuses } from '../services/api';

const empty = {
  stats: {},
  charts: { by_status: [], status_pie: [], by_type: [], trend_per_day: [], by_location: [] }
};

const emptyStatusForm = { key: '', label: '', color: '#6B7280', insertAfter: '' };

export default function CertDashboardPage() {
  const [data, setData] = useState(empty);
  const [error, setError] = useState('');

  // Position-ordered report statuses, managed right here — adding one
  // (with a chosen position) makes it immediately usable everywhere:
  // the Reports page filter, the report detail dropdown/timeline, and
  // the mobile app's own report screens read from this same list.
  const [statuses, setStatuses] = useState([]);
  const [statusForm, setStatusForm] = useState(emptyStatusForm);
  const [statusError, setStatusError] = useState('');
  const [savingStatus, setSavingStatus] = useState(false);

  const loadStatuses = useCallback(() => {
    return getReportStatuses().then(setStatuses).catch((err) => setStatusError(err.message));
  }, []);

  useEffect(() => {
    getCertDashboard()
      .then(setData)
      .catch((err) => setError(err.message));
    loadStatuses();
  }, [loadStatuses]);

  async function submitNewStatus(event) {
    event.preventDefault();
    setStatusError('');

    if (!statusForm.key.trim() || !statusForm.label.trim()) {
      setStatusError('Both a key and a label are required.');
      return;
    }

    setSavingStatus(true);
    try {
      await createReportStatus(statusForm);
      setStatusForm(emptyStatusForm);
      await loadStatuses();
    } catch (err) {
      setStatusError(err.message);
    } finally {
      setSavingStatus(false);
    }
  }

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <p className="eyebrow">CERT</p>
          <h2>Incident Response Dashboard</h2>
        </div>
      </div>

      {error ? <p className="error-banner">{error}</p> : null}

      <div className="stats-grid">
        <Link className="stat-link" to="/reports">
          <StatCard
            label="Total incidents"
            value={data.stats.total_incidents || 0}
            hint="All reports submitted through the app"
            accent="blue"
            icon="T"
          />
        </Link>
        <Link className="stat-link" to="/reports?status=PENDING">
          <StatCard
            label="Pending"
            value={data.stats.pending || 0}
            hint="Not yet reviewed"
            accent="gold"
            icon="P"
          />
        </Link>
        <Link className="stat-link" to="/reports?status=UNDER_REVIEW">
          <StatCard
            label="Under review"
            value={data.stats.under_review || 0}
            hint="Currently being investigated"
            accent="teal"
            icon="U"
          />
        </Link>
        <Link className="stat-link" to="/reports?status=RESOLVED">
          <StatCard
            label="Resolved"
            value={data.stats.resolved || 0}
            hint="Closed out reports"
            accent="rose"
            icon="R"
          />
        </Link>
      </div>

      <div className="two-column-grid">
        <BarChart title="Incidents, last 14 days" items={data.charts.trend_per_day || []} tone="gold" />
        <BarChart
          title="Incidents by status"
          subtitle="Tap a bar to see those reports"
          items={data.charts.by_status || []}
          tone="rose"
          linkFor={(item) => `/reports?status=${encodeURIComponent(item.label)}`}
        />
      </div>

      <div className="two-column-grid">
        <BarChart
          title="Incidents by type"
          subtitle="Tap a bar to see those reports"
          items={data.charts.by_type || []}
          tone="blue"
          linkFor={(item) => `/reports?type=${encodeURIComponent(item.label)}`}
        />
        <BarChart
          title="Incidents by location"
          subtitle="Tap a bar to see those reports"
          items={data.charts.by_location || []}
          tone="teal"
          linkFor={(item) =>
            ['Other', 'Unspecified'].includes(item.label)
              ? null
              : `/reports?location=${encodeURIComponent(item.label)}`
          }
        />
      </div>

      <SectionCard
        title="Manage Report Statuses"
        subtitle="Add a new status and choose exactly where it sits in the workflow. It shows up immediately on the Reports page and in the mobile app — no app update needed."
      >
        <ol className="status-steps" style={{ marginBottom: 'var(--space-4)' }}>
          {statuses.map((s) => (
            <li key={s.key} className="status-step">
              <span
                className="status-step-dot"
                style={{ background: s.color, borderColor: s.color }}
              />
              <span>{s.label}</span>
              <span className="muted-text" style={{ marginLeft: 4 }}>({s.key})</span>
            </li>
          ))}
        </ol>

        {statusError ? <p className="error-text">{statusError}</p> : null}

        <form className="form" onSubmit={submitNewStatus}>
          <div className="form-grid">
            <label>
              Key (internal, no spaces)
              <input
                value={statusForm.key}
                onChange={(e) => setStatusForm((c) => ({ ...c, key: e.target.value.toUpperCase() }))}
                placeholder="e.g. PROPOSAL"
                required
              />
            </label>
            <label>
              Label (shown to staff and citizens)
              <input
                value={statusForm.label}
                onChange={(e) => setStatusForm((c) => ({ ...c, label: e.target.value }))}
                placeholder="e.g. Proposal"
                required
              />
            </label>
          </div>
          <div className="form-grid">
            <label>
              Color
              <input
                type="color"
                value={statusForm.color}
                onChange={(e) => setStatusForm((c) => ({ ...c, color: e.target.value }))}
              />
            </label>
            <label>
              Position — insert after
              <select
                value={statusForm.insertAfter}
                onChange={(e) => setStatusForm((c) => ({ ...c, insertAfter: e.target.value }))}
              >
                <option value="">(at the very start)</option>
                {statuses.map((s) => (
                  <option key={s.key} value={s.key}>{s.label}</option>
                ))}
              </select>
            </label>
          </div>
          <button type="submit" disabled={savingStatus}>
            {savingStatus ? 'Adding…' : 'Add status'}
          </button>
        </form>
      </SectionCard>
    </div>
  );
}
