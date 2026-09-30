import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import LocationPicker from '../components/LocationPicker';
import SectionCard from '../components/SectionCard';
import { CONTENT_CONFIGS } from '../content/contentConfig';
import useConfirm from '../hooks/useConfirm';

export default function ContentFormPage({ configKey }) {
  const config = CONTENT_CONFIGS[configKey];
  const { id } = useParams();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const [form, setForm] = useState({ ...config.emptyForm });
  const [item, setItem] = useState(null);
  const [imageFile, setImageFile] = useState(null);
  const [imagePreview, setImagePreview] = useState('');
  const [removeImage, setRemoveImage] = useState(false);
  const [loading, setLoading] = useState(isEdit);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [tab, setTab] = useState('details');
  const [confirm, confirmDialog] = useConfirm();

  const ExtraPanel = config.ExtraPanel;
  const extraTabs = config.extraTabs || [];
  const tabs = isEdit && extraTabs.length ? [{ key: 'details', label: 'Details' }, ...extraTabs] : null;

  useEffect(() => {
    setTab('details');

    if (!isEdit) {
      setForm({ ...config.emptyForm });
      setItem(null);
      setImageFile(null);
      setImagePreview('');
      setRemoveImage(false);
      setLoading(false);
      return;
    }

    setLoading(true);
    config
      .fetchOne(id)
      .then((data) => {
        setItem(data);
        setForm({ ...config.emptyForm, ...config.toForm(data) });
        setImagePreview(data.image || '');
      })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [config, id, isEdit]);

  function setField(name, value) {
    setForm((current) => ({ ...current, [name]: value }));
  }

  function handleImageChange(event) {
    const file = event.target.files?.[0] || null;
    setImageFile(file);
    setRemoveImage(false);
    if (file) setImagePreview(URL.createObjectURL(file));
  }

  async function handleSubmit(event) {
    event.preventDefault();

    const pushing = config.sendsPush && form.is_published;
    const ok = await confirm({
      title: isEdit
        ? `Save this ${config.singular.toLowerCase()}?`
        : `${config.createLabel || `Publish ${config.singular.toLowerCase()}`}?`,
      message: pushing
        ? 'Every app user will get a push notification about this.'
        : 'This updates what appears in the mobile app.',
      confirmLabel: isEdit ? 'Save' : config.createLabel || 'Publish'
    });
    if (!ok) return;

    setSaving(true);
    setError('');

    const payload = { ...form };
    if (imageFile) payload.image = imageFile;
    if (removeImage) payload.remove_image = true;

    try {
      if (isEdit) {
        await config.update(id, payload);
      } else {
        await config.create(payload);
      }
      // Always return to the list after a successful save.
      navigate(config.basePath);
    } catch (err) {
      setError(err.message);
      setSaving(false);
    }
  }

  async function handleDelete() {
    const ok = await confirm({
      title: `Delete this ${config.singular.toLowerCase()}?`,
      message: 'This cannot be undone.',
      confirmLabel: `Delete ${config.singular.toLowerCase()}`
    });
    if (!ok) return;

    try {
      await config.remove(id);
      navigate(config.basePath, { replace: true });
    } catch (err) {
      setError(err.message);
    }
  }

  const formCard = (
    <SectionCard
      title={isEdit ? `Edit ${config.singular.toLowerCase()}` : `Create ${config.singular.toLowerCase()}`}
      subtitle={config.formSubtitle}
    >
      <form className="form" onSubmit={handleSubmit}>
        {config.fields.map((field) => {
          if (field.type === 'image') {
            return (
              <div key={field.name}>
                <label>
                  {field.label}
                  <input type="file" accept="image/*" onChange={handleImageChange} />
                </label>
                {imagePreview && !removeImage ? (
                  <>
                    <img className="image-preview" src={imagePreview} alt="Preview" />
                    {isEdit && item?.image ? (
                      <label className="checkbox">
                        <input
                          type="checkbox"
                          checked={removeImage}
                          onChange={(e) => {
                            setRemoveImage(e.target.checked);
                            if (e.target.checked) {
                              setImageFile(null);
                              setImagePreview('');
                            }
                          }}
                        />
                        <span>Remove current image</span>
                      </label>
                    ) : null}
                  </>
                ) : null}
              </div>
            );
          }

          if (field.type === 'checkbox') {
            return (
              <label className="checkbox" key={field.name}>
                <input
                  type="checkbox"
                  checked={Boolean(form[field.name])}
                  onChange={(e) => setField(field.name, e.target.checked)}
                />
                <span>{field.label}</span>
              </label>
            );
          }

          if (field.type === 'location') {
            return (
              <div key={field.name}>
                <label style={{ display: 'block', marginBottom: 'var(--space-2)' }}>
                  {field.label}
                </label>
                <LocationPicker
                  value={{
                    location: form.location || '',
                    latitude: form.latitude ?? null,
                    longitude: form.longitude ?? null
                  }}
                  onChange={(next) =>
                    setForm((current) => ({
                      ...current,
                      location: next.location,
                      latitude: next.latitude,
                      longitude: next.longitude
                    }))
                  }
                />
              </div>
            );
          }

          if (field.type === 'select') {
            return (
              <label key={field.name}>
                {field.label}
                <select
                  value={form[field.name] || ''}
                  onChange={(e) => setField(field.name, e.target.value)}
                >
                  {field.options.map((opt) => (
                    <option key={opt.value} value={opt.value}>
                      {opt.label}
                    </option>
                  ))}
                </select>
              </label>
            );
          }

          if (field.type === 'textarea') {
            return (
              <label key={field.name}>
                {field.label}
                <textarea
                  value={form[field.name] || ''}
                  onChange={(e) => setField(field.name, e.target.value)}
                  rows={field.rows || 6}
                  required={field.required}
                />
              </label>
            );
          }

          return (
            <label key={field.name}>
              {field.label}
              <input
                type={field.type === 'text' ? 'text' : field.type}
                value={form[field.name] || ''}
                onChange={(e) => setField(field.name, e.target.value)}
                required={field.required}
              />
            </label>
          );
        })}

        <div className="button-row">
          <button type="submit" disabled={saving}>
            {saving
              ? 'Saving…'
              : isEdit
              ? `Save ${config.singular.toLowerCase()}`
              : config.createLabel || `Publish ${config.singular.toLowerCase()}`}
          </button>
          <button
            type="button"
            className="secondary-button"
            onClick={() => navigate(config.basePath)}
          >
            Cancel
          </button>
        </div>
      </form>
    </SectionCard>
  );

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <Link className="back-link" to={config.basePath}>
            ← Back to {config.plural.toLowerCase()}
          </Link>
          <h2>
            {isEdit
              ? form.title || `Edit ${config.singular.toLowerCase()}`
              : `New ${config.singular.toLowerCase()}`}
          </h2>
        </div>
        {isEdit ? (
          <button type="button" className="secondary-button danger-button" onClick={handleDelete}>
            Delete
          </button>
        ) : null}
      </div>

      {confirmDialog}

      {error ? <p className="error-banner">{error}</p> : null}

      {loading ? (
        <p className="muted-text">Loading…</p>
      ) : (
        <>
          {isEdit && config.countField && typeof item?.[config.countField] === 'number' ? (
            <p className="registration-tally">
              <strong>{item[config.countField]}</strong>{' '}
              {item[config.countField] === 1 ? 'person has' : 'people have'} registered for this{' '}
              {config.singular.toLowerCase()}.
            </p>
          ) : null}

          {tabs ? (
            <div className="tab-bar">
              {tabs.map((t) => (
                <button
                  key={t.key}
                  type="button"
                  className={`tab-button${tab === t.key ? ' tab-button-active' : ''}`}
                  onClick={() => setTab(t.key)}
                >
                  {t.label}
                </button>
              ))}
            </div>
          ) : null}

          {!tabs || tab === 'details' ? formCard : null}

          {tabs && tab !== 'details' && ExtraPanel && item ? (
            <ExtraPanel item={item} activeTab={tab} />
          ) : null}
        </>
      )}
    </div>
  );
}
