import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import ListToolbar from '../components/ListToolbar';
import PaginationControls from '../components/PaginationControls';
import SectionCard from '../components/SectionCard';
import StatCard from '../components/StatCard';
import { getReports, getReportStatuses } from '../services/api';

// These four keep their fixed, theme-matched tile design (accent
// colors are CSS tokens, not raw hex — a status CERT adds later
// doesn't get a themed tile slot, but it's still fully filterable and
// countable below, and shows correctly in the reports table itself.
const STATUS_TILES = [
  { value: 'ALL', label: 'Total incidents', accent: 'blue', icon: 'T', hint: 'All reports submitted through the app' },
  { value: 'PENDING', label: 'Pending', accent: 'gold', icon: 'P', hint: 'Not yet reviewed' },
  { value: 'UNDER_REVIEW', label: 'Under review', accent: 'teal', icon: 'U', hint: 'Currently being investigated' },
  { value: 'RESOLVED', label: 'Resolved', accent: 'rose', icon: 'R', hint: 'Closed out reports' }
];

const pageSize = 10;

// The list is polled so a report submitted from the mobile app shows up
// here without the admin having to reload the page.
const POLL_INTERVAL_MS = 20000;

export default function ReportsPage() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();

  // All known statuses, position-ordered — includes anything CERT has
  // added beyond the original three, so the filter dropdown and counts
  // stay accurate without a code change.
  const [statuses, setStatuses] = useState([]);
  const validStatuses = useMemo(
    () => ['ALL', ...statuses.map((s) => s.key)],
    [statuses]
  );

  const statusParam = (searchParams.get('status') || 'ALL').toUpperCase();
  const statusFilter = validStatuses.includes(statusParam) ? statusParam : 'ALL';
  const typeFilter = searchParams.get('type') || '';
  const locationFilter = searchParams.get('location') || '';

  const [reports, setReports] = useState([]);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);

  useEffect(() => {
    getReportStatuses().then(setStatuses).catch(() => {});
  }, []);

  // Merge a change into the current query string so status / type /
  // location filters compose instead of clobbering each other.
  function updateParams(patch) {
    const next = new URLSearchParams(searchParams);
    Object.entries(patch).forEach(([key, value]) => {
      if (value && !(key === 'status' && value === 'ALL')) {
        next.set(key, value);
      } else {
        next.delete(key);
      }
    });
    setPage(1);
    setSearchParams(next, { replace: true });
  }

  function tilePath(value) {
    const next = new URLSearchParams(searchParams);
    if (value && value !== 'ALL') {
      next.set('status', value);
    } else {
      next.delete('status');
    }
    const qs = next.toString();
    return qs ? `/reports?${qs}` : '/reports';
  }

  const loadReports = useCallback(() => {
    return getReports()
      .then(setReports)
      .catch((err) => setError(err.message));
  }, []);

  useEffect(() => {
    loadReports();
    const timer = setInterval(loadReports, POLL_INTERVAL_MS);
    return () => clearInterval(timer);
  }, [loadReports]);

  // Keep pagination sane when the view is narrowed from a chart or tile.
  useEffect(() => {
    setPage(1);
  }, [statusFilter, typeFilter, locationFilter]);

  function setStatusFilter(value) {
    updateParams({ status: value });
  }

  const counts = useMemo(() => {
    const base = { ALL: reports.length };
    statuses.forEach((s) => { base[s.key] = 0; });
    reports.forEach((report) => {
      if (base[report.status] !== undefined) base[report.status] += 1;
    });
    return base;
  }, [reports, statuses]);

  const filteredReports = useMemo(() => {
    const query = search.trim().toLowerCase();
    return reports.filter((report) => {
      const matchesSearch =
        !query ||
        [
          report.reference_number,
          report.incident_type,
          report.platform,
          report.description,
          report.reporter_name,
          report.location
        ].some((value) => String(value || '').toLowerCase().includes(query));
      const matchesStatus = statusFilter === 'ALL' || report.status === statusFilter;
      const matchesType = !typeFilter || report.incident_type === typeFilter;
      const matchesLocation = !locationFilter || report.location === locationFilter;
      return matchesSearch && matchesStatus && matchesType && matchesLocation;
    });
  }, [reports, search, statusFilter, typeFilter, locationFilter]);

  const totalPages = Math.max(1, Math.ceil(filteredReports.length / pageSize));
  const pagedReports = filteredReports.slice((page - 1) * pageSize, page * pageSize);

  const activeTile = STATUS_TILES.find((tile) => tile.value === statusFilter);

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <p className="eyebrow">CERT</p>
          <h2>Incident Reports</h2>
        </div>
      </div>

      {error ? <p className="error-banner">{error}</p> : null}

      <div className="stats-grid">
        {STATUS_TILES.map((tile) => (
          <Link
            key={tile.value}
            className={`stat-link${statusFilter === tile.value ? ' stat-link-active' : ''}`}
            to={tilePath(tile.value)}
            replace
          >
            <StatCard
              label={tile.label}
              value={counts[tile.value] ?? 0}
              hint={tile.hint}
              accent={tile.accent}
              icon={tile.icon}
            />
          </Link>
        ))}
      </div>

      <SectionCard
        title={activeTile && activeTile.value !== 'ALL' ? `${activeTile.label} reports` : 'All incident reports'}
        subtitle="Click any report to open its full details. Updates automatically as new reports arrive."
      >
        <ListToolbar
          searchValue={search}
          onSearchChange={(value) => {
            setSearch(value);
            setPage(1);
          }}
          searchPlaceholder="Search reports"
          filterValue={statusFilter}
          onFilterChange={setStatusFilter}
          filterOptions={[
            { value: 'ALL', label: 'All statuses' },
            ...statuses.map((s) => ({ value: s.key, label: s.label }))
          ]}
          resultLabel={`${filteredReports.length} report(s)`}
        />

        {typeFilter || locationFilter ? (
          <div className="filter-chips">
            {typeFilter ? (
              <button type="button" className="filter-chip" onClick={() => updateParams({ type: '' })}>
                Type: {typeFilter} <span aria-hidden="true">✕</span>
              </button>
            ) : null}
            {locationFilter ? (
              <button
                type="button"
                className="filter-chip"
                onClick={() => updateParams({ location: '' })}
              >
                Location: {locationFilter} <span aria-hidden="true">✕</span>
              </button>
            ) : null}
          </div>
        ) : null}

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Reference</th>
                <th>Type</th>
                <th>Platform</th>
                <th>Location</th>
                <th>Status</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              {pagedReports.map((report) => (
                <tr
                  key={report.reference_number}
                  className="clickable-row"
                  onClick={() =>
                    navigate(`/reports/${encodeURIComponent(report.reference_number)}`, {
                      state: { report }
                    })
                  }
                >
                  <td>{report.reference_number}</td>
                  <td>{report.incident_type}</td>
                  <td>{report.platform}</td>
                  <td>{report.location || '—'}</td>
                  <td>{report.status_display}</td>
                  <td>{new Date(report.created_at).toLocaleString()}</td>
                </tr>
              ))}
              {!pagedReports.length ? (
                <tr>
                  <td colSpan="6" className="muted-text">
                    No reports match this view yet.
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
        <PaginationControls page={page} totalPages={totalPages} onPageChange={setPage} />
      </SectionCard>
    </div>
  );
}
