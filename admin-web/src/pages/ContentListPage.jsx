import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import ListToolbar from '../components/ListToolbar';
import PaginationControls from '../components/PaginationControls';
import { CONTENT_CONFIGS } from '../content/contentConfig';
import useConfirm from '../hooks/useConfirm';

const pageSize = 12;

export default function ContentListPage({ configKey }) {
  const config = CONTENT_CONFIGS[configKey];
  const navigate = useNavigate();

  const [items, setItems] = useState([]);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [confirm, confirmDialog] = useConfirm();

  useEffect(() => {
    setItems([]);
    setSearch('');
    setPage(1);
    config
      .fetchList()
      .then(setItems)
      .catch((err) => setError(err.message));
  }, [config]);

  const filtered = useMemo(() => {
    const query = search.trim().toLowerCase();
    if (!query) return items;
    return items.filter((item) =>
      config.searchFields.some((field) =>
        String(item[field] || '').toLowerCase().includes(query)
      )
    );
  }, [items, search, config]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / pageSize));
  const paged = filtered.slice((page - 1) * pageSize, page * pageSize);

  async function handleDelete(item) {
    const ok = await confirm({
      title: `Delete “${item.title}”?`,
      message: `This ${config.singular.toLowerCase()} will be removed for good.`,
      confirmLabel: `Delete ${config.singular.toLowerCase()}`
    });
    if (!ok) return;

    setError('');
    try {
      await config.remove(item.id);
      setItems((current) => current.filter((entry) => entry.id !== item.id));
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div className="page">
      {confirmDialog}
      <div className="page-header">
        <div>
          <p className="eyebrow">COMMS</p>
          <h2>{config.plural}</h2>
        </div>
        <Link className="primary-link-button" to={`${config.basePath}/new`}>
          + Add {config.singular.toLowerCase()}
        </Link>
      </div>

      {error ? <p className="error-banner">{error}</p> : null}

      <ListToolbar
        searchValue={search}
        onSearchChange={(value) => {
          setSearch(value);
          setPage(1);
        }}
        searchPlaceholder={`Search ${config.plural.toLowerCase()}`}
        resultLabel={`${filtered.length} ${config.plural.toLowerCase()}`}
      />

      <div className="content-card-list">
        {paged.map((item) => {
          const date = item[config.dateField];
          return (
            <article
              key={item.id}
              className="content-card"
              onClick={() => navigate(`${config.basePath}/${item.id}`)}
            >
              <div className="content-card-thumb">
                {item.image ? (
                  <img src={item.image} alt="" />
                ) : (
                  <span className="content-card-thumb-empty">No image</span>
                )}
              </div>

              <div className="content-card-main">
                <h3>{item.title}</h3>
                <div className="content-card-meta">
                  {date ? (
                    <span>
                      {config.dateLabel} {new Date(date).toLocaleDateString()}
                    </span>
                  ) : (
                    <span>No date</span>
                  )}
                  {'is_published' in item ? (
                    <span className="pill">
                      {item.is_published
                        ? config.publishedLabels?.on || 'Published'
                        : config.publishedLabels?.off || 'Draft'}
                    </span>
                  ) : null}
                  {config.countField && typeof item[config.countField] === 'number' ? (
                    <span className="pill pill-accent">
                      {item[config.countField]} {config.countLabel || 'registered'}
                    </span>
                  ) : null}
                  {item.category ? <span className="pill">{item.category}</span> : null}
                </div>
              </div>

              <div className="content-card-actions" onClick={(e) => e.stopPropagation()}>
                <button
                  type="button"
                  className="secondary-button danger-button"
                  onClick={() => handleDelete(item)}
                >
                  Delete
                </button>
              </div>
            </article>
          );
        })}

        {!paged.length ? (
          <p className="muted-text">
            No {config.plural.toLowerCase()} yet. Use “Add {config.singular.toLowerCase()}” to create one.
          </p>
        ) : null}
      </div>

      <PaginationControls page={page} totalPages={totalPages} onPageChange={setPage} />
    </div>
  );
}
