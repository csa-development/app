import { useEffect, useState } from 'react';
import SectionCard from '../components/SectionCard';
import useConfirm from '../hooks/useConfirm';
import { getContactPage, updateContactPage } from '../services/api';

const emptyForm = {
  office_address: '',
  latitude: '',
  longitude: '',
  phone: '',
  emergency_hotline: '',
  email: '',
  whatsapp_channel_url: '',
  twitter_url: '',
  instagram_url: '',
  linkedin_url: '',
  facebook_url: ''
};

export default function ContactCsaPage() {
  const [form, setForm] = useState(emptyForm);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [confirm, confirmDialog] = useConfirm();

  useEffect(() => {
    getContactPage()
      .then((item) => setForm(item))
      .catch((err) => setError(err.message));
  }, []);

  function handleChange(event) {
    const { name, value } = event.target;
    setForm((current) => ({ ...current, [name]: value }));
  }

  async function handleSubmit(event) {
    event.preventDefault();

    const ok = await confirm({
      title: 'Update the Contact Us page?',
      message: 'This changes the contact details and links shown in the app.',
      confirmLabel: 'Update page'
    });
    if (!ok) return;

    setMessage('');
    setError('');
    try {
      const saved = await updateContactPage(form);
      setForm(saved);
      setMessage('Contact Us page updated successfully.');
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div className="page">
      {confirmDialog}
      <div className="page-header">
        <div>
          <p className="eyebrow">Site Content</p>
          <h2>Contact Us</h2>
        </div>
      </div>

      <SectionCard
        title="Contact CSA page"
        subtitle="Office location, phone/email and social links shown on the app's Contact CSA page."
      >
        <form className="form" onSubmit={handleSubmit}>
          <label>
            Office address
            <input name="office_address" value={form.office_address} onChange={handleChange} />
          </label>
          <div className="form-grid">
            <label>
              Map latitude
              <input
                name="latitude"
                type="number"
                step="any"
                value={form.latitude}
                onChange={handleChange}
              />
            </label>
            <label>
              Map longitude
              <input
                name="longitude"
                type="number"
                step="any"
                value={form.longitude}
                onChange={handleChange}
              />
            </label>
          </div>
          <div className="form-grid">
            <label>
              Phone
              <input name="phone" value={form.phone} onChange={handleChange} />
            </label>
            <label>
              Emergency hotline
              <input
                name="emergency_hotline"
                value={form.emergency_hotline}
                onChange={handleChange}
              />
            </label>
          </div>
          <label>
            Email
            <input name="email" value={form.email} onChange={handleChange} />
          </label>
          <label>
            WhatsApp channel URL
            <input
              name="whatsapp_channel_url"
              value={form.whatsapp_channel_url}
              onChange={handleChange}
            />
          </label>
          <div className="form-grid">
            <label>
              X (Twitter) URL
              <input name="twitter_url" value={form.twitter_url} onChange={handleChange} />
            </label>
            <label>
              Instagram URL
              <input name="instagram_url" value={form.instagram_url} onChange={handleChange} />
            </label>
            <label>
              LinkedIn URL
              <input name="linkedin_url" value={form.linkedin_url} onChange={handleChange} />
            </label>
            <label>
              Facebook URL
              <input name="facebook_url" value={form.facebook_url} onChange={handleChange} />
            </label>
          </div>

          <div className="button-row">
            <button type="submit">Save Contact Us page</button>
          </div>
          {message ? <p className="success-text">{message}</p> : null}
          {error ? <p className="error-text">{error}</p> : null}
        </form>
      </SectionCard>
    </div>
  );
}
