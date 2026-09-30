import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import ListToolbar from '../components/ListToolbar';
import PaginationControls from '../components/PaginationControls';
import SectionCard from '../components/SectionCard';
import useConfirm from '../hooks/useConfirm';
import { deleteCertificate, getCertificates } from '../services/api';

const EXPIRY_HORIZON_MS = 30 * 24 * 60 * 60 * 1000;

// Maps the ?status= value from the IT dashboard cards to the list filter.
const PARAM_TO_FILTER = {
  active: 'ACTIVE',
  inactive: 'INACTIVE',
  expiring: 'EXPIRING'
};

export default function CertificatesPage() {
  const navigate = useNavigate();
  const [items, setItems] = useState([]);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [confirm, confirmDialog] = useConfirm();
  const [searchParams, setSearchParams] = useSearchParams();

  const statusFilter = PARAM_TO_FILTER[searchParams.get('status')] || 'ALL';
  function setStatusFilter(value) {
    setPage(1);
    const param = Object.entries(PARAM_TO_FILTER).find(([, v]) => v === value)?.[0];
    setSearchParams(param ? { status: param } : {}, { replace: true });
  }

  useEffect(() => {
    getCertificates().then(setItems).catch((err) => setError(err.message));
  }, []);

  async function handleDelete(item) {
    const ok = await confirm({
      title: `Delete certificate ${item.certificate_number}?`,
      message: 'This removes the record the public verification flow checks against.',
      confirmLabel: 'Delete certificate'
    });
    if (!ok) return;
    try {
      await deleteCertificate(item.id);
      setItems((current) => current.filter((entry) => entry.id !== item.id));
    } catch (err) {
      setError(err.message);
    }
  }

  const filteredItems = useMemo(() => {
    const query = search.trim().toLowerCase();
    return items.filter((item) => {
      const matchesSearch =
        !query ||
        [
          item.certificate_number,
          item.holder_name,
          item.organisation,
          item.certificate_type_display
        ].some((value) => String(value || '').toLowerCase().includes(query));
      let matchesStatus = true;
      if (statusFilter === 'ACTIVE') matchesStatus = item.is_active;
      else if (statusFilter === 'INACTIVE') matchesStatus = !item.is_active;
      else if (statusFilter === 'EXPIRING') {
        const until = item.expiry_date
          ? new Date(item.expiry_date).getTime() - Date.now()
          : Infinity;
        matchesStatus = item.is_active && until > 0 && until <= EXPIRY_HORIZON_MS;
      }
      return matchesSearch && matchesStatus;
    });
  }, [items, search, statusFilter]);

  const pageSize = 8;
  const totalPages = Math.max(1, Math.ceil(filteredItems.length / pageSize));
  const pagedItems = filteredItems.slice((page - 1) * pageSize, page * pageSize);

  return (
    <div className="page">
      {confirmDialog}
      <div className="page-header">
        <div>
          <p className="eyebrow">Certificates</p>
          <h2>Cert Records</h2>
        </div>
        <Link className="primary-link-button" to="/certificates/new">
          + Add certificate
        </Link>
      </div>

      {error ? <p className="error-banner">{error}</p> : null}

      <SectionCard
        title="Certificate records"
        subtitle="These are the records the public verification flow checks against."
      >
        <ListToolbar
          searchValue={search}
          onSearchChange={(value) => {
            setSearch(value);
            setPage(1);
          }}
          searchPlaceholder="Search certificates"
          filterValue={statusFilter}
          onFilterChange={setStatusFilter}
          filterOptions={[
            { value: 'ALL', label: 'All certificates' },
            { value: 'ACTIVE', label: 'Active only' },
            { value: 'EXPIRING', label: 'Expiring soon' },
            { value: 'INACTIVE', label: 'Inactive only' }
          ]}
          resultLabel={`${filteredItems.length} certificate(s)`}
        />
        <div className="list">
          {pagedItems.map((item) => (
            <article
              key={item.id}
              className="list-item clickable-row"
              onClick={() => navigate(`/certificates/${item.id}`)}
            >
              <div>
                <h3>{item.certificate_number}</h3>
                <p>
                  {item.holder_name} {item.organisation ? `• ${item.organisation}` : ''}
                </p>
                <div className="info-row">
                  <span>{item.certificate_type_display}</span>
                  <span>Issue {new Date(item.issue_date).toLocaleDateString()}</span>
                  <span>Expiry {new Date(item.expiry_date).toLocaleDateString()}</span>
                </div>
              </div>
              <div className="stacked-meta" onClick={(e) => e.stopPropagation()}>
                <span className={`pill ${item.is_active ? 'pill-success' : 'pill-danger'}`}>
                  {item.is_active ? 'Active' : 'Inactive'}
                </span>
                <button
                  type="button"
                  className="secondary-button danger-button btn-sm"
                  onClick={() => handleDelete(item)}
                >
                  Delete
                </button>
              </div>
            </article>
          ))}
          {!pagedItems.length ? (
            <p className="muted-text">No certificates match this view.</p>
          ) : null}
        </div>
        <PaginationControls page={page} totalPages={totalPages} onPageChange={setPage} />
      </SectionCard>
    </div>
  );
}
