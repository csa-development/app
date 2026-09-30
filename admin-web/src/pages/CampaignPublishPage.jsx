import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import SectionCard from '../components/SectionCard';
import useConfirm from '../hooks/useConfirm';
import { saveCampaign } from '../services/api';

const emptyForm = {
  title: '',
  description: '',
  start_date: '',
  end_date: '',
  target_audience: '',
  category: 'OTHER',
  is_published: true,
  image: null,
  imagePreview: ''
};

const categoryOptions = [
  'AWARENESS', 'NCSAM', 'CHALLENGE', 'WORKSHOP', 'TRAINING',
  'SENSITISATION', 'CYBER_HYGIENE', 'OUTREACH', 'OTHER'
];

export default function CampaignPublishPage() {
  const navigate = useNavigate();
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState('');
  const [confirm, confirmDialog] = useConfirm();

  function handleChange(event) {
    const { name, type, value, checked } = event.target;
    setForm((current) => ({ ...current, [name]: type === 'checkbox' ? checked : value }));
  }

  function handleImageChange(event) {
    const file = event.target.files?.[0] || null;
    setForm((current) => ({ ...current, image: file, imagePreview: file ? URL.createObjectURL(file) : current.imagePreview }));
  }

  async function handleSubmit(event) {
    event.preventDefault();

    const ok = await confirm({
      title: 'Publish this campaign?',
      message: form.is_published
        ? 'It will appear in the mobile app straight away.'
        : 'It will be saved as a draft.',
      confirmLabel: 'Publish campaign'
    });
    if (!ok) return;

    setError('');
    try {
      const saved = await saveCampaign(form);
      navigate(`/campaigns/${saved.id}`);
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div className="page">
      {confirmDialog}
      <SectionCard title="Publish campaign" subtitle="Create a new campaign record for the mobile app.">
        <form className="form" onSubmit={handleSubmit}>
          <div className="form-grid">
            <label>
              Title
              <input name="title" value={form.title} onChange={handleChange} required />
            </label>
            <label>
              Target audience
              <input name="target_audience" value={form.target_audience} onChange={handleChange} />
            </label>
          </div>
          <label>
            Description
            <textarea name="description" value={form.description} onChange={handleChange} rows="5" required />
          </label>
          <div className="form-grid">
            <label>
              Start date
              <input type="date" name="start_date" value={form.start_date} onChange={handleChange} required />
            </label>
            <label>
              End date
              <input type="date" name="end_date" value={form.end_date} onChange={handleChange} />
            </label>
          </div>
          <div className="form-grid">
            <label>
              Category
              <select name="category" value={form.category} onChange={handleChange}>
                {categoryOptions.map((option) => <option key={option} value={option}>{option}</option>)}
              </select>
            </label>
            <label>
              Image
              <input type="file" accept="image/*" onChange={handleImageChange} />
            </label>
          </div>
          <label className="checkbox">
            <input type="checkbox" name="is_published" checked={form.is_published} onChange={handleChange} />
            <span>Published</span>
          </label>
          {form.imagePreview ? <img className="image-preview" src={form.imagePreview} alt="Preview" /> : null}
          <div className="button-row">
            <button type="submit">Publish campaign</button>
            <button type="button" className="secondary-button" onClick={() => navigate('/campaigns')}>Cancel</button>
          </div>
          {error ? <p className="error-text">{error}</p> : null}
        </form>
      </SectionCard>
    </div>
  );
}
