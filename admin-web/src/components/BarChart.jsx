import { Link } from 'react-router-dom';

// `linkFor(item)` — optional. When it returns a path, each bar becomes a
// link (e.g. to a filtered list of the records behind that bar).
export default function BarChart({ title, subtitle, items, tone = 'blue', linkFor }) {
  const maxValue = Math.max(...items.map((item) => item.value), 1);

  return (
    <section className="section-card">
      <div className="section-header">
        <div>
          <h2>{title}</h2>
          {subtitle ? <p>{subtitle}</p> : null}
        </div>
      </div>

      <div className="chart-list">
        {items.length ? (
          items.map((item) => {
            const body = (
              <>
                <div className="chart-meta">
                  <span>{item.label}</span>
                  <strong>{item.value}</strong>
                </div>
                <div className="chart-track">
                  <div
                    className={`chart-fill chart-fill-${tone}`}
                    style={{ width: `${(item.value / maxValue) * 100}%` }}
                  />
                </div>
              </>
            );

            const href = linkFor ? linkFor(item) : null;

            return href ? (
              <Link key={item.label} to={href} className="chart-row chart-row-link">
                {body}
              </Link>
            ) : (
              <div key={item.label} className="chart-row">
                {body}
              </div>
            );
          })
        ) : (
          <p className="muted-text">No data available yet.</p>
        )}
      </div>
    </section>
  );
}
