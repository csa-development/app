const SLICE_TONES = ['blue', 'teal', 'gold', 'slate', 'rose', 'violet'];

function buildSlices(items) {
  const total = items.reduce((sum, item) => sum + (item.value || 0), 0);
  let cursor = 0;

  return items.map((item, index) => {
    const share = total ? item.value / total : 0;
    const start = cursor;
    cursor += share;
    return {
      ...item,
      tone: SLICE_TONES[index % SLICE_TONES.length],
      percentage: item.percentage ?? Math.round(share * 1000) / 10,
      start,
      end: cursor
    };
  });
}

function describeArc(start, end) {
  // start/end are fractions of a full circle (0..1). Draws on a
  // 32-radius circle centered at (36, 36).
  const toPoint = (fraction) => {
    const angle = fraction * 2 * Math.PI - Math.PI / 2;
    return [36 + 32 * Math.cos(angle), 36 + 32 * Math.sin(angle)];
  };

  if (end - start >= 0.9999) {
    // A full circle can't be drawn as a single SVG arc path.
    return `M 36 4 A 32 32 0 1 1 35.99 4 Z`;
  }

  const [x1, y1] = toPoint(start);
  const [x2, y2] = toPoint(end);
  const largeArc = end - start > 0.5 ? 1 : 0;

  return `M 36 36 L ${x1} ${y1} A 32 32 0 ${largeArc} 1 ${x2} ${y2} Z`;
}

export default function PieChart({ title, subtitle, items = [] }) {
  const slices = buildSlices(items.filter((item) => item.value > 0));

  return (
    <section className="section-card">
      <div className="section-header">
        <div>
          <h2>{title}</h2>
          {subtitle ? <p>{subtitle}</p> : null}
        </div>
      </div>

      {slices.length ? (
        <div className="pie-chart-wrap">
          <svg viewBox="0 0 72 72" className="pie-chart-svg" role="img" aria-label={title}>
            {slices.map((slice) => (
              <path
                key={slice.label}
                d={describeArc(slice.start, slice.end)}
                className={`pie-slice pie-slice-${slice.tone}`}
              />
            ))}
          </svg>

          <ul className="pie-legend">
            {slices.map((slice) => (
              <li key={slice.label} className="pie-legend-item">
                <span className={`pie-swatch pie-swatch-${slice.tone}`} />
                <span className="pie-legend-label">{slice.label}</span>
                <span className="pie-legend-value">
                  {slice.value} &middot; {slice.percentage}%
                </span>
              </li>
            ))}
          </ul>
        </div>
      ) : (
        <p className="muted-text">No data available yet.</p>
      )}
    </section>
  );
}
