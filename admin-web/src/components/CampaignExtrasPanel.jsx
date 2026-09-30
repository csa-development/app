import { useCallback, useEffect, useState } from 'react';
import RegistrationsPanel from './RegistrationsPanel';
import SectionCard from './SectionCard';
import useConfirm from '../hooks/useConfirm';
import {
  checkInCampaignRegistration,
  createCampaignGallery,
  createCampaignSchedule,
  createCampaignSpeaker,
  deleteCampaignGallery,
  deleteCampaignSchedule,
  deleteCampaignSpeaker,
  getCampaignDetail,
  getCampaignRegistrations,
  updateCampaignGallery,
  updateCampaignSchedule,
  updateCampaignSpeaker
} from '../services/api';

const emptyGallery = { id: null, caption: '', order: 0, image: null, imagePreview: '' };
const emptySchedule = {
  id: null,
  week_number: 1,
  day: '',
  start_time: '',
  end_time: '',
  session_title: '',
  speaker: '',
  venue: ''
};
const emptySpeaker = {
  id: null,
  name: '',
  title: '',
  organisation: '',
  bio: '',
  order: 0,
  photo: null,
  imagePreview: ''
};

// Schedule / Speakers / Gallery management for one campaign. Rendered on
// the NCSAM (campaign) detail page; `activeTab` selects which section to
// show. `item` is the campaign.
export default function CampaignExtrasPanel({ item: campaign, activeTab = 'schedule' }) {
  const campaignId = campaign.id;
  const [detail, setDetail] = useState(null);
  const [error, setError] = useState('');
  const [galleryForm, setGalleryForm] = useState(emptyGallery);
  const [scheduleForm, setScheduleForm] = useState(emptySchedule);
  const [speakerForm, setSpeakerForm] = useState(emptySpeaker);
  const [confirm, confirmDialog] = useConfirm();

  async function removeItem(label, remove, itemId) {
    const ok = await confirm({
      title: `Delete this ${label}?`,
      message: 'This cannot be undone.',
      confirmLabel: 'Delete'
    });
    if (!ok) return;
    try {
      await remove(itemId);
      await loadDetail();
    } catch (err) {
      setError(err.message);
    }
  }

  const loadDetail = useCallback(() => {
    return getCampaignDetail(campaignId)
      .then(setDetail)
      .catch((err) => setError(err.message));
  }, [campaignId]);

  useEffect(() => {
    loadDetail();
  }, [loadDetail]);

  async function submitSchedule(event) {
    event.preventDefault();
    try {
      if (scheduleForm.id) {
        await updateCampaignSchedule(scheduleForm.id, scheduleForm);
      } else {
        await createCampaignSchedule(campaignId, scheduleForm);
      }
      setScheduleForm(emptySchedule);
      await loadDetail();
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
        await createCampaignSpeaker(campaignId, speakerForm);
      }
      setSpeakerForm(emptySpeaker);
      await loadDetail();
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
        await createCampaignGallery(campaignId, galleryForm);
      }
      setGalleryForm(emptyGallery);
      await loadDetail();
    } catch (err) {
      setError(err.message);
    }
  }

  if (activeTab === 'registrations') {
    return (
      <RegistrationsPanel
        id={campaignId}
        fetchRegistrations={getCampaignRegistrations}
        checkIn={checkInCampaignRegistration}
      />
    );
  }

  if (!detail) {
    return (
      <SectionCard title="Loading…" subtitle="">
        {error ? <p className="error-text">{error}</p> : <p className="muted-text">Loading…</p>}
      </SectionCard>
    );
  }

  const scheduleSection = (
    <SectionCard title="Schedule" subtitle="Sessions shown on the mobile app's Schedule tab.">
      <form className="form" onSubmit={submitSchedule}>
        <div className="form-grid">
          <label>
            Week number
            <input
              type="number"
              value={scheduleForm.week_number}
              onChange={(e) => setScheduleForm((c) => ({ ...c, week_number: e.target.value }))}
            />
          </label>
          <label>
            Day
            <input
              value={scheduleForm.day}
              onChange={(e) => setScheduleForm((c) => ({ ...c, day: e.target.value }))}
            />
          </label>
        </div>
        <label>
          Session title
          <input
            value={scheduleForm.session_title}
            onChange={(e) => setScheduleForm((c) => ({ ...c, session_title: e.target.value }))}
            required
          />
        </label>
        <div className="form-grid">
          <label>
            Start time
            <input
              type="time"
              value={scheduleForm.start_time}
              onChange={(e) => setScheduleForm((c) => ({ ...c, start_time: e.target.value }))}
              required
            />
          </label>
          <label>
            End time
            <input
              type="time"
              value={scheduleForm.end_time}
              onChange={(e) => setScheduleForm((c) => ({ ...c, end_time: e.target.value }))}
            />
          </label>
        </div>
        <div className="form-grid">
          <label>
            Speaker
            <input
              value={scheduleForm.speaker}
              onChange={(e) => setScheduleForm((c) => ({ ...c, speaker: e.target.value }))}
            />
          </label>
          <label>
            Venue
            <input
              value={scheduleForm.venue}
              onChange={(e) => setScheduleForm((c) => ({ ...c, venue: e.target.value }))}
            />
          </label>
        </div>
        <div className="button-row">
          <button type="submit">{scheduleForm.id ? 'Update session' : 'Add session'}</button>
          {scheduleForm.id ? (
            <button
              type="button"
              className="secondary-button"
              onClick={() => setScheduleForm(emptySchedule)}
            >
              Cancel
            </button>
          ) : null}
        </div>
      </form>
      <div className="list compact-list">
        {detail.schedule.map((s) => (
          <article key={s.id} className="list-item">
            <div>
              <h3>{s.session_title}</h3>
              <p>
                Week {s.week_number} {s.day ? `• ${s.day}` : ''} • {s.start_time}
                {s.end_time ? ` - ${s.end_time}` : ''}
              </p>
            </div>
            <div className="stacked-meta">
              <button type="button" className="secondary-button" onClick={() => setScheduleForm(s)}>
                Edit
              </button>
              <button
                type="button"
                className="secondary-button danger-button"
                onClick={() => removeItem('session', deleteCampaignSchedule, s.id)}
              >
                Delete
              </button>
            </div>
          </article>
        ))}
        {!detail.schedule.length ? <p className="muted-text">No sessions yet.</p> : null}
      </div>
    </SectionCard>
  );

  const speakersSection = (
    <SectionCard title="Speakers" subtitle="Shown on the mobile app's Speakers tab.">
      <form className="form" onSubmit={submitSpeaker}>
        <div className="form-grid">
          <label>
            Name
            <input
              value={speakerForm.name}
              onChange={(e) => setSpeakerForm((c) => ({ ...c, name: e.target.value }))}
              required
            />
          </label>
          <label>
            Title
            <input
              value={speakerForm.title}
              onChange={(e) => setSpeakerForm((c) => ({ ...c, title: e.target.value }))}
            />
          </label>
        </div>
        <div className="form-grid">
          <label>
            Organisation
            <input
              value={speakerForm.organisation}
              onChange={(e) => setSpeakerForm((c) => ({ ...c, organisation: e.target.value }))}
            />
          </label>
          <label>
            Order
            <input
              type="number"
              value={speakerForm.order}
              onChange={(e) => setSpeakerForm((c) => ({ ...c, order: e.target.value }))}
            />
          </label>
        </div>
        <label>
          Bio
          <textarea
            rows="4"
            value={speakerForm.bio}
            onChange={(e) => setSpeakerForm((c) => ({ ...c, bio: e.target.value }))}
          />
        </label>
        <label>
          Photo
          <input
            type="file"
            accept="image/*"
            onChange={(e) => {
              const file = e.target.files?.[0] || null;
              setSpeakerForm((c) => ({
                ...c,
                photo: file,
                imagePreview: file ? URL.createObjectURL(file) : c.imagePreview
              }));
            }}
          />
        </label>
        {speakerForm.imagePreview ? (
          <img className="image-preview" src={speakerForm.imagePreview} alt="Speaker preview" />
        ) : null}
        <div className="button-row">
          <button type="submit">{speakerForm.id ? 'Update speaker' : 'Add speaker'}</button>
          {speakerForm.id ? (
            <button
              type="button"
              className="secondary-button"
              onClick={() => setSpeakerForm(emptySpeaker)}
            >
              Cancel
            </button>
          ) : null}
        </div>
      </form>
      <div className="list compact-list">
        {detail.speakers.map((sp) => (
          <article key={sp.id} className="list-item">
            <div>
              <h3>{sp.name}</h3>
              <p>
                {sp.title || 'No title'} {sp.organisation ? `• ${sp.organisation}` : ''}
              </p>
            </div>
            <div className="stacked-meta">
              <button
                type="button"
                className="secondary-button"
                onClick={() =>
                  setSpeakerForm({
                    id: sp.id,
                    name: sp.name,
                    title: sp.title,
                    organisation: sp.organisation,
                    bio: sp.bio,
                    order: sp.order,
                    photo: null,
                    imagePreview: sp.photo || ''
                  })
                }
              >
                Edit
              </button>
              <button
                type="button"
                className="secondary-button danger-button"
                onClick={() => removeItem('speaker', deleteCampaignSpeaker, sp.id)}
              >
                Delete
              </button>
            </div>
          </article>
        ))}
        {!detail.speakers.length ? <p className="muted-text">No speakers yet.</p> : null}
      </div>
    </SectionCard>
  );

  const gallerySection = (
    <SectionCard title="Gallery" subtitle="Shown on the mobile app's Gallery tab.">
      <form className="form" onSubmit={submitGallery}>
        <div className="form-grid">
          <label>
            Caption
            <input
              value={galleryForm.caption}
              onChange={(e) => setGalleryForm((c) => ({ ...c, caption: e.target.value }))}
            />
          </label>
          <label>
            Order
            <input
              type="number"
              value={galleryForm.order}
              onChange={(e) => setGalleryForm((c) => ({ ...c, order: e.target.value }))}
            />
          </label>
        </div>
        <label>
          Image
          <input
            type="file"
            accept="image/*"
            onChange={(e) => {
              const file = e.target.files?.[0] || null;
              setGalleryForm((c) => ({
                ...c,
                image: file,
                imagePreview: file ? URL.createObjectURL(file) : c.imagePreview
              }));
            }}
          />
        </label>
        {galleryForm.imagePreview ? (
          <img className="image-preview" src={galleryForm.imagePreview} alt="Gallery preview" />
        ) : null}
        <div className="button-row">
          <button type="submit">
            {galleryForm.id ? 'Update gallery item' : 'Add gallery item'}
          </button>
          {galleryForm.id ? (
            <button
              type="button"
              className="secondary-button"
              onClick={() => setGalleryForm(emptyGallery)}
            >
              Cancel
            </button>
          ) : null}
        </div>
      </form>
      <div className="list compact-list">
        {detail.gallery.map((g) => (
          <article key={g.id} className="list-item">
            <div>
              <h3>{g.caption || 'Untitled image'}</h3>
              {g.image ? (
                <img className="content-thumb" src={g.image} alt={g.caption || 'Gallery'} />
              ) : null}
            </div>
            <div className="stacked-meta">
              <span className="pill">Order {g.order}</span>
              <button
                type="button"
                className="secondary-button"
                onClick={() =>
                  setGalleryForm({
                    id: g.id,
                    caption: g.caption,
                    order: g.order,
                    image: null,
                    imagePreview: g.image || ''
                  })
                }
              >
                Edit
              </button>
              <button
                type="button"
                className="secondary-button danger-button"
                onClick={() => removeItem('gallery image', deleteCampaignGallery, g.id)}
              >
                Delete
              </button>
            </div>
          </article>
        ))}
        {!detail.gallery.length ? <p className="muted-text">No gallery images yet.</p> : null}
      </div>
    </SectionCard>
  );

  return (
    <>
      {confirmDialog}
      {error ? <p className="error-banner">{error}</p> : null}
      {activeTab === 'schedule' ? scheduleSection : null}
      {activeTab === 'speakers' ? speakersSection : null}
      {activeTab === 'gallery' ? gallerySection : null}
    </>
  );
}
