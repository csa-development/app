import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import BarChart from '../components/BarChart';
import PieChart from '../components/PieChart';
import SectionCard from '../components/SectionCard';
import StatCard from '../components/StatCard';
import { getItDashboard, getContentDashboard, getCertificatesDashboard } from '../services/api';

// A StatCard that navigates to a filtered list when clicked.
function LinkStat({ to, ...props }) {
  return (
    <Link className="stat-link" to={to}>
      <StatCard {...props} />
    </Link>
  );
}

const emptyUsers = {
  stats: {},
  charts: { signups_per_day: [], status_mix: [], status_pie: [] }
};

const emptyContent = {
  stats: {},
  charts: { content_mix: [], content_type_pie: [], article_category_mix: [] }
};

const emptyCertificates = {
  stats: {},
  charts: { by_type: [], type_pie: [] },
  recent_certificates: []
};

export default function ItDashboardPage() {
  const [userData, setUserData] = useState(emptyUsers);
  const [contentData, setContentData] = useState(emptyContent);
  const [certData, setCertData] = useState(emptyCertificates);
  const [error, setError] = useState('');

  useEffect(() => {
    getItDashboard()
      .then(setUserData)
      .catch((err) => setError(err.message));

    getContentDashboard()
      .then(setContentData)
      .catch((err) => setError(err.message));

    getCertificatesDashboard()
      .then(setCertData)
      .catch((err) => setError(err.message));
  }, []);

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <p className="eyebrow">IT</p>
          <h2>IT Dashboard</h2>
        </div>
      </div>

      {error ? <p className="error-banner">{error}</p> : null}

      <div className="stats-grid">
        <LinkStat
          to="/users"
          label="Total users"
          value={userData.stats.total_users || 0}
          hint="Accounts stored in Django"
          accent="blue"
          icon="U"
        />
        <LinkStat
          to="/users?status=active"
          label="Active accounts"
          value={userData.stats.active_users || 0}
          hint="Currently able to sign in"
          accent="teal"
          icon="A"
        />
        <LinkStat
          to="/users?status=disabled"
          label="Disabled accounts"
          value={userData.stats.disabled_users || 0}
          hint="Flagged or deactivated"
          accent="rose"
          icon="D"
        />
        <LinkStat
          to="/users?joined=recent"
          label="Recent signups"
          value={userData.stats.recent_signups_count || 0}
          hint="New accounts, last 7 days"
          accent="gold"
          icon="S"
        />
      </div>

      <div className="two-column-grid">
        <BarChart title="Signups, last 7 days" items={userData.charts.signups_per_day || []} tone="blue" />
        <PieChart title="Active vs disabled" items={userData.charts.status_pie || []} />
      </div>

      <div className="stats-grid">
        <StatCard
          label="Published articles"
          value={contentData.stats.published_articles_count || 0}
          hint="News, alerts, advisories and notices"
          accent="blue"
          icon="A"
        />
        <LinkStat
          to="/breaking-news"
          label="Breaking stories"
          value={contentData.stats.breaking_news_count || 0}
          hint="Marked as breaking"
          accent="rose"
          icon="B"
        />
        <LinkStat
          to="/events"
          label="Upcoming events"
          value={contentData.stats.upcoming_events_count || 0}
          hint="Published and not yet past"
          accent="teal"
          icon="E"
        />
        <LinkStat
          to="/campaigns"
          label="Active campaigns"
          value={contentData.stats.active_campaigns_count || 0}
          hint="Published and not yet ended"
          accent="gold"
          icon="C"
        />
      </div>

      <div className="two-column-grid">
        <BarChart title="Content mix" items={contentData.charts.content_mix || []} tone="blue" />
        <PieChart title="Content type mix" items={contentData.charts.content_type_pie || []} />
      </div>

      <BarChart
        title="Article category mix"
        items={contentData.charts.article_category_mix || []}
        tone="teal"
      />

      <div className="page-header">
        <div>
          <p className="eyebrow">Certificates</p>
          <h2>Certificate Registry</h2>
        </div>
      </div>

      <div className="stats-grid">
        <LinkStat
          to="/certificates"
          label="Total certificates"
          value={certData.stats.total_certificates || 0}
          hint="All issued certificate records"
          accent="blue"
          icon="C"
        />
        <LinkStat
          to="/certificates?status=active"
          label="Active certificates"
          value={certData.stats.active_certificates || 0}
          hint="Currently valid for verification"
          accent="teal"
          icon="A"
        />
        <LinkStat
          to="/certificates?status=expiring"
          label="Expiring soon"
          value={certData.stats.expiring_soon_count || 0}
          hint="Active certificates expiring within 30 days"
          accent="gold"
          icon="E"
        />
        <LinkStat
          to="/certificates?status=inactive"
          label="Inactive certificates"
          value={certData.stats.inactive_certificates || 0}
          hint="Revoked or no longer valid"
          accent="rose"
          icon="I"
        />
      </div>

      <div className="two-column-grid">
        <BarChart title="Certificates by type" items={certData.charts.by_type || []} tone="blue" />
        <PieChart title="Certificate type mix" items={certData.charts.type_pie || []} />
      </div>

      <SectionCard title="Recent applications" subtitle="Most recently issued certificates.">
        <div className="list">
          {(certData.recent_certificates || []).map((item) => (
            <article key={item.id} className="list-item">
              <div>
                <h3>{item.certificate_number}</h3>
                <p>{item.holder_name}{item.organisation ? ` • ${item.organisation}` : ''}</p>
                <div className="info-row">
                  <span>{item.certificate_type_display}</span>
                  <span>Issued {new Date(item.issue_date).toLocaleDateString()}</span>
                  <span>Expires {new Date(item.expiry_date).toLocaleDateString()}</span>
                </div>
              </div>
              <span className="pill">{item.is_active ? 'Active' : 'Inactive'}</span>
            </article>
          ))}
          {!certData.recent_certificates?.length ? (
            <p className="muted-text">No certificates recorded yet.</p>
          ) : null}
        </div>
      </SectionCard>
    </div>
  );
}
