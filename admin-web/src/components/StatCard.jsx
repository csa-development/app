const accentMap = {
  users: 'blue',
  alerts: 'gold',
  breaking: 'teal',
  reports: 'rose'
};

export default function StatCard({ label, value, hint, accent = 'blue', icon = '•' }) {
  return (
    <article className={`stat-card stat-card-${accentMap[accent] || accent}`}>
      <div className="stat-topline">
        <div className={`stat-icon stat-icon-${accentMap[accent] || accent}`}>{icon}</div>
        <p className="stat-label">{label}</p>
      </div>
      <h3 className="stat-value">{value}</h3>
      <p className="stat-hint">{hint}</p>
    </article>
  );
}
