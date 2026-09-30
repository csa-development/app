import { useEffect, useState } from 'react';
import SectionCard from '../components/SectionCard';
import useConfirm from '../hooks/useConfirm';
import { getAboutPage, updateAboutPage } from '../services/api';

const emptyForm = {
  intro_paragraph_1: '',
  intro_paragraph_2: '',
  image: null,
  imagePreview: '',
  mandate_text: '',
  mission_text: '',
  vision_text: '',
  value_1_title: '',
  value_1_description: '',
  value_2_title: '',
  value_2_description: '',
  value_3_title: '',
  value_3_description: '',
  value_4_title: '',
  value_4_description: '',
  value_5_title: '',
  value_5_description: '',
  value_6_title: '',
  value_6_description: ''
};

export default function AboutCsaPage() {
  const [form, setForm] = useState(emptyForm);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [confirm, confirmDialog] = useConfirm();

  useEffect(() => {
    getAboutPage()
      .then((item) => setForm({ ...item, image: null, imagePreview: item.image || '' }))
      .catch((err) => setError(err.message));
  }, []);

  function handleChange(event) {
    const { name, value } = event.target;
    setForm((current) => ({ ...current, [name]: value }));
  }

  function handleImageChange(event) {
    const file = event.target.files?.[0] || null;
    setForm((current) => ({
      ...current,
      image: file,
      imagePreview: file ? URL.createObjectURL(file) : current.imagePreview
    }));
  }

  async function handleSubmit(event) {
    event.preventDefault();

    const ok = await confirm({
      title: 'Update the About Us page?',
      message: 'This changes what every app user sees on the About CSA screen.',
      confirmLabel: 'Update page'
    });
    if (!ok) return;

    setMessage('');
    setError('');
    try {
      const saved = await updateAboutPage(form);
      setForm({ ...saved, image: null, imagePreview: saved.image || '' });
      setMessage('About Us page updated successfully.');
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
          <h2>About Us</h2>
        </div>
      </div>

      <SectionCard
        title="About CSA page"
        subtitle="Text and image shown on the app's About CSA page."
      >
        <form className="form" onSubmit={handleSubmit}>
          <label>
            Intro paragraph 1
            <textarea
              name="intro_paragraph_1"
              value={form.intro_paragraph_1}
              onChange={handleChange}
              rows="4"
            />
          </label>
          <label>
            Intro paragraph 2
            <textarea
              name="intro_paragraph_2"
              value={form.intro_paragraph_2}
              onChange={handleChange}
              rows="4"
            />
          </label>
          <label>
            Page image
            <input type="file" accept="image/*" onChange={handleImageChange} />
          </label>
          {form.imagePreview ? (
            <img className="image-preview" src={form.imagePreview} alt="Preview" />
          ) : null}
          <label>
            Mandate
            <textarea name="mandate_text" value={form.mandate_text} onChange={handleChange} rows="4" />
          </label>
          <label>
            Mission
            <textarea name="mission_text" value={form.mission_text} onChange={handleChange} rows="3" />
          </label>
          <label>
            Vision
            <textarea name="vision_text" value={form.vision_text} onChange={handleChange} rows="2" />
          </label>

          <div className="section-header">
            <h2>Core values</h2>
          </div>

          <div className="form-grid">
            {[1, 2, 3, 4, 5, 6].map((n) => (
              <div className="form" key={n}>
                <label>
                  {`Value ${n} title`}
                  <input
                    name={`value_${n}_title`}
                    value={form[`value_${n}_title`]}
                    onChange={handleChange}
                  />
                </label>
                <label>
                  {`Value ${n} description`}
                  <textarea
                    name={`value_${n}_description`}
                    value={form[`value_${n}_description`]}
                    onChange={handleChange}
                    rows="3"
                  />
                </label>
              </div>
            ))}
          </div>

          <div className="button-row">
            <button type="submit">Save About Us page</button>
          </div>
          {message ? <p className="success-text">{message}</p> : null}
          {error ? <p className="error-text">{error}</p> : null}
        </form>
      </SectionCard>
    </div>
  );
}
