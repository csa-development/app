import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import ListToolbar from '../components/ListToolbar';
import SectionCard from '../components/SectionCard';
import { getCampaigns } from '../services/api';

export default function CampaignsListPage() {
  const navigate = useNavigate();
  const [items, setItems] = useState([]);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');

  useEffect(() => {
    getCampaigns().then(setItems).catch((err) => setError(err.message));
  }, []);

  const filteredItems = useMemo(() => {
    const query = search.trim().toLowerCase();
    if (!query) return items;
    return items.filter((item) =>
      [item.title, item.category_display, item.target_audience].some(
        (value) => String(value || '').toLowerCase().includes(query)
      )
    );
  }, [items, search]);

  return (
    <div className="page">
      <SectionCard
        title="All campaigns"
        subtitle="Every campaign on record. Click one to view, edit, or manage its details."
        action={
          <button type="button" onClick={() => navigate('/campaigns/publish')}>
            Publish campaign
          </button>
        }
      >
        {error ? <p className="error-text">{error}</p> : null}
        <ListToolbar
          searchValue={search}
          onSearchChange={setSearch}
          searchPlaceholder="Search campaigns"
          resultLabel={`${filteredItems.length} campaign(s)`}
        />
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Category</th>
                <th>Start date</th>
                <th>End date</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {filteredItems.map((item) => (
                <tr key={item.id} className="clickable-row" onClick={() => navigate(`/campaigns/${item.id}`)}>
                  <td>{item.title}</td>
                  <td>{item.category_display}</td>
                  <td>{item.start_date ? new Date(item.start_date).toLocaleDateString() : '—'}</td>
                  <td>{item.end_date ? new Date(item.end_date).toLocaleDateString() : '—'}</td>
                  <td>
                    <span className="pill">{item.is_published ? 'Published' : 'Draft'}</span>
                  </td>
                </tr>
              ))}
              {!filteredItems.length ? (
                <tr>
                  <td colSpan={5} className="muted-text">No campaigns recorded yet.</td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </SectionCard>
    </div>
  );
}
