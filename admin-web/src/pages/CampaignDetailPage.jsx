import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import SectionCard from '../components/SectionCard';
import useConfirm from '../hooks/useConfirm';
import {
  createCampaignGallery,
  createCampaignRelatedNews,
  createCampaignSchedule,
  createCampaignSpeaker,
  deleteCampaign,
  deleteCampaignGallery,
  deleteCampaignRelatedNews,
  deleteCampaignSchedule,
  deleteCampaignSpeaker,
  getCampaignDetail,
  updateCampaign,
  updateCampaignGallery,
  updateCampaignSchedule,
  updateCampaignSpeaker
} from '../services/api';

const emptyGallery = { id: null, caption: '', order: 0, image: null, imagePreview: '' };
const emptySchedule = { id: null, week_number: 1, day: '', start_time: '', end_time: '', session_title: '', speaker: '', venue: '' };
const emptySpeaker = { id: null, name: '', title: '', organisation: '', bio: '', order: 0, photo: null, imagePreview: '' };

const categoryOptions = [
  'AWARENESS', 'NCSAM', 'CHALLENGE', 'WORKSHOP', 'TRAINING',
  'SENSITISATION', 'CYBER_HYGIENE', 'OUTREACH', 'OTHER'
];

export default function CampaignDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();

  const [detail, setDetail] = useState(null);
  const [form, setForm] = useState(null);
  const [galleryForm, setGalleryForm] = useState(emptyGallery);
  const [scheduleForm, setScheduleForm] = useState(emptySchedule);
  const [speakerForm, setSpeakerForm] = useState(emptySpeaker);
  const [selectedArticleId, setSelectedArticleId] = useState('');
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [confirm, confirmDialog] = useConfirm();

  async function confirmRemove(label, remove, itemId, verb = 'Delete') {
    const ok = await confirm({
      title: `${verb} this ${label}?`,
      message: 'This cannot be undone.',
      confirmLabel: verb
    });
    if (!ok) return;
    try {
      await remove(itemId);
      await load();
    } catch (err) {
      setError(err.message);
    }
  }

  async function load() {
    try {
      const data = await getCampaignDetail(id);
      setDetail(data);
      setForm({
        title: data.item.title,
        description: data.item.description,
        start_date: data.item.start_date || '',
        end_date: data.item.end_date || '',
        target_audience: data.item.target_audience || '',
        category: data.item.category,
        is_published: data.item.is_published,
        image: null,
        imagePreview: data.item.image || ''
      });
      setSelectedArticleId(data.available_news?.[0]?.id ? String(data.available_news[0].id) : '');
    } catch (err) {
      setError(err.message);
    }
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

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
      title: 'Save changes to this campaign?',
      message: 'This updates what appears in the mobile app.',
      confirmLabel: 'Save campaign'
    });
    if (!ok) return;

    setMessage('');
    setError('');
    try {
      await updateCampaign(id, form);
      setMessage('Campaign updated successfully.');
      await load();
    } catch (err) {
      setError(err.message);
    }
  }

  async function handleDelete() {
    const ok = await confirm({
      title: 'Delete this campaign?',
      message: 'The campaign and all its schedule, speakers, and gallery items will be removed. This cannot be undone.',
      confirmLabel: 'Delete campaign'
    });
    if (!ok) return;
    try {
      await deleteCampaign(id);
      navigate('/campaigns');
    } catch (err) {
      setError(err.message);
    }
  }

  async function submitGallery(event) {
    event.preventDefault();
    try {
      if (galleryForm.id) {
        await updateCampaignGallery(galleryForm.id, galleryForm);
      } else {
        await createCampaignGallery(id, galleryForm);
      }
      setGalleryForm(emptyGallery);
      await load();
    } catch (err) {
      setError(err.message);
    }
  }

  async function submitSchedule(event) {
    event.preventDefault();
    try {
      if (scheduleForm.id) {
        await updateCampaignSchedule(scheduleForm.id, scheduleForm);
      } else {
        await createCampaignSchedule(id, scheduleForm);
      }
      setScheduleForm(emptySchedule);
      await load();
    } catch (err) {
      setError(err.message);
    }
  }

  async function submitSpeaker(event) {
    event.preventDefault();
    try {
      if (speakerForm.id) {
        await updateCampaignSpeaker(speakerForm.id, speakerForm);
      } else {
        await createCampaignSpeaker(id, speakerForm);
      }
      setSpeakerForm(emptySpeaker);
      await load();
    } catch (err) {
      setError(err.message);
    }
  }

  if (!detail || !form) {
    return (
      <div className="page">
        {error ? <p className="error-text">{error}</p> : <p className="muted-text">Loading campaign…</p>}
      </div>
    );
  }

  return (
    <div className="page">
      {confirmDialog}
      <div className="page two-column-grid">
        <SectionCard title={detail.item.title} subtitle="Edit this campaign's details or remove it entirely.">
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
              <button type="submit">Update campaign</button>
              <button type="button" className="secondary-button" onClick={() => navigate('/campaigns')}>Back to all campaigns</button>
              <button type="button" className="secondary-button danger-button" onClick={handleDelete}>Delete campaign</button>
            </div>
            {message ? <p className="success-text">{message}</p> : null}
            {error ? <p className="error-text">{error}</p> : null}
          </form>
        </SectionCard>

        <SectionCard title="Campaign gallery" subtitle="Add and manage gallery images for this campaign.">
          <form className="form" onSubmit={submitGallery}>
            <div className="form-grid">
              <label>
                Caption
                <input value={galleryForm.caption} onChange={(e) => setGalleryForm((current) => ({ ...current, caption: e.target.value }))} />
              </label>
              <label>
                Order
                <input type="number" value={galleryForm.order} onChange={(e) => setGalleryForm((current) => ({ ...current, order: e.target.value }))} />
              </label>
            </div>
            <label>
              Image
              <input type="file" accept="image/*" onChange={(e) => {
                const file = e.target.files?.[0] || null;
                setGalleryForm((current) => ({ ...current, image: file, imagePreview: file ? URL.createObjectURL(file) : current.imagePreview }));
              }} />
            </label>
            {galleryForm.imagePreview ? <img className="image-preview" src={galleryForm.imagePreview} alt="Gallery preview" /> : null}
            <div className="button-row">
              <button type="submit">{galleryForm.id ? 'Update gallery item' : 'Add gallery item'}</button>
              {galleryForm.id ? <button type="button" className="secondary-button" onClick={() => setGalleryForm(emptyGallery)}>Cancel</button> : null}
            </div>
          </form>
          <div className="list compact-list">
            {detail.gallery.map((item) => (
              <article key={item.id} className="list-item">
                <div>
                  <h3>{item.caption || 'Untitled image'}</h3>
                  {item.image ? <img className="content-thumb" src={item.image} alt={item.caption || 'Gallery'} /> : null}
                </div>
                <div className="stacked-meta">
                  <span className="pill">Order {item.order}</span>
                  <button type="button" className="secondary-button" onClick={() => setGalleryForm({ id: item.id, caption: item.caption, order: item.order, image: null, imagePreview: item.image || '' })}>Edit</button>
                  <button type="button" className="secondary-button danger-button" onClick={() => confirmRemove('gallery image', deleteCampaignGallery, item.id)}>Delete</button>
                </div>
              </article>
            ))}
          </div>
        </SectionCard>
      </div>

      <div className="page two-column-grid">
        <SectionCard title="Campaign schedule" subtitle="Add sessions, weeks, and venue details.">
          <form className="form" onSubmit={submitSchedule}>
            <div className="form-grid">
              <label>
                Week number
                <input type="number" value={scheduleForm.week_number} onChange={(e) => setScheduleForm((current) => ({ ...current, week_number: e.target.value }))} />
              </label>
              <label>
                Day
                <input value={scheduleForm.day} onChange={(e) => setScheduleForm((current) => ({ ...current, day: e.target.value }))} />
              </label>
            </div>
            <label>
              Session title
              <input value={scheduleForm.session_title} onChange={(e) => setScheduleForm((current) => ({ ...current, session_title: e.target.value }))} required />
            </label>
            <div className="form-grid">
              <label>
                Start time
                <input type="time" value={scheduleForm.start_time} onChange={(e) => setScheduleForm((current) => ({ ...current, start_time: e.target.value }))} required />
              </label>
              <label>
                End time
                <input type="time" value={scheduleForm.end_time} onChange={(e) => setScheduleForm((current) => ({ ...current, end_time: e.target.value }))} />
              </label>
            </div>
            <div className="form-grid">
              <label>
                Speaker
                <input value={scheduleForm.speaker} onChange={(e) => setScheduleForm((current) => ({ ...current, speaker: e.target.value }))} />
              </label>
              <label>
                Venue
                <input value={scheduleForm.venue} onChange={(e) => setScheduleForm((current) => ({ ...current, venue: e.target.value }))} />
              </label>
            </div>
            <div className="button-row">
              <button type="submit">{scheduleForm.id ? 'Update schedule item' : 'Add schedule item'}</button>
              {scheduleForm.id ? <button type="button" className="secondary-button" onClick={() => setScheduleForm(emptySchedule)}>Cancel</button> : null}
            </div>
          </form>
          <div className="list compact-list">
            {detail.schedule.map((item) => (
              <article key={item.id} className="list-item">
                <div>
                  <h3>{item.session_title}</h3>
                  <p>Week {item.week_number} {item.day ? `• ${item.day}` : ''} • {item.start_time} {item.end_time ? `- ${item.end_time}` : ''}</p>
                </div>
                <div className="stacked-meta">
                  <button type="button" className="secondary-button" onClick={() => setScheduleForm(item)}>Edit</button>
                  <button type="button" className="secondary-button danger-button" onClick={() => confirmRemove('session', deleteCampaignSchedule, item.id)}>Delete</button>
                </div>
              </article>
            ))}
          </div>
        </SectionCard>

        <SectionCard title="Campaign speakers" subtitle="Manage speaker bios and speaker photos.">
          <form className="form" onSubmit={submitSpeaker}>
            <div className="form-grid">
              <label>
                Name
                <input value={speakerForm.name} onChange={(e) => setSpeakerForm((current) => ({ ...current, name: e.target.value }))} required />
              </label>
              <label>
                Title
                <input value={speakerForm.title} onChange={(e) => setSpeakerForm((current) => ({ ...current, title: e.target.value }))} />
              </label>
            </div>
            <div className="form-grid">
              <label>
                Organisation
                <input value={speakerForm.organisation} onChange={(e) => setSpeakerForm((current) => ({ ...current, organisation: e.target.value }))} />
              </label>
              <label>
                Order
                <input type="number" value={speakerForm.order} onChange={(e) => setSpeakerForm((current) => ({ ...current, order: e.target.value }))} />
              </label>
            </div>
            <label>
              Bio
              <textarea rows="4" value={speakerForm.bio} onChange={(e) => setSpeakerForm((current) => ({ ...current, bio: e.target.value }))} />
            </label>
            <label>
              Photo
              <input type="file" accept="image/*" onChange={(e) => {
                const file = e.target.files?.[0] || null;
                setSpeakerForm((current) => ({ ...current, photo: file, imagePreview: file ? URL.createObjectURL(file) : current.imagePreview }));
              }} />
            </label>
            {speakerForm.imagePreview ? <img className="image-preview" src={speakerForm.imagePreview} alt="Speaker preview" /> : null}
            <div className="button-row">
              <button type="submit">{speakerForm.id ? 'Update speaker' : 'Add speaker'}</button>
              {speakerForm.id ? <button type="button" className="secondary-button" onClick={() => setSpeakerForm(emptySpeaker)}>Cancel</button> : null}
            </div>
          </form>
          <div className="list compact-list">
            {detail.speakers.map((item) => (
              <article key={item.id} className="list-item">
                <div>
                  <h3>{item.name}</h3>
                  <p>{item.title || 'No title'} {item.organisation ? `• ${item.organisation}` : ''}</p>
                </div>
                <div className="stacked-meta">
                  <button type="button" className="secondary-button" onClick={() => setSpeakerForm({ id: item.id, name: item.name, title: item.title, organisation: item.organisation, bio: item.bio, order: item.order, photo: null, imagePreview: item.photo || '' })}>Edit</button>
                  <button type="button" className="secondary-button danger-button" onClick={() => confirmRemove('speaker', deleteCampaignSpeaker, item.id)}>Delete</button>
                </div>
              </article>
            ))}
          </div>
        </SectionCard>
      </div>

      <SectionCard title="Related news" subtitle="Connect published news items to this campaign.">
        <div className="form-grid">
          <label>
            Available news
            <select value={selectedArticleId} onChange={(e) => setSelectedArticleId(e.target.value)}>
              {detail.available_news.map((article) => (
                <option key={article.id} value={article.id}>{article.title}</option>
              ))}
            </select>
          </label>
          <div className="button-row align-end">
            <button type="button" onClick={async () => {
              if (!selectedArticleId) return;
              await createCampaignRelatedNews(id, selectedArticleId);
              await load();
            }}>Attach news</button>
          </div>
        </div>
        <div className="list compact-list">
          {detail.related_news.map((item) => (
            <article key={item.id} className="list-item">
              <div>
                <h3>{item.article_title}</h3>
                <p>{item.article_category}</p>
              </div>
              <button type="button" className="secondary-button danger-button" onClick={() => confirmRemove('linked article', deleteCampaignRelatedNews, item.id, 'Detach')}>Detach</button>
            </article>
          ))}
        </div>
      </SectionCard>
    </div>
  );
}
