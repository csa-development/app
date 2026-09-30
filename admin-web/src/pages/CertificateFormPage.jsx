import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import SectionCard from '../components/SectionCard';
import useConfirm from '../hooks/useConfirm';
import {
  deleteCertificate,
  getCertificate,
  saveCertificate,
  updateCertificate
} from '../services/api';

const emptyForm = {
  certificate_number: '',
  certificate_type: 'CSP',
  holder_name: '',
  organisation: '',
  holder_email: '',
  issue_date: '',
  expiry_date: '',
  is_active: true
};

function toForm(item) {
  return {
    certificate_number: item.certificate_number || '',
    certificate_type: item.certificate_type || 'CSP',
    holder_name: item.holder_name || '',
    organisation: item.organisation || '',
    holder_email: item.holder_email || '',
    issue_date: item.issue_date || '',
    expiry_date: item.expiry_date || '',
    is_active: item.is_active ?? true
  };
}

export default function CertificateFormPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const [form, setForm] = useState(emptyForm);
  const [loading, setLoading] = useState(isEdit);
  const [error, setError] = useState('');
  const [confirm, confirmDialog] = useConfirm();

  useEffect(() => {
    if (!isEdit) return;
    getCertificate(id)
      .then((item) => setForm(toForm(item)))
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  function handleChange(event) {
    const { name, type, value, checked } = event.target;
    setForm((current) => ({ ...current, [name]: type === 'checkbox' ? checked : value }));
  }

  async function handleSubmit(event) {
    event.preventDefault();

    const willNotify = form.is_active && form.holder_email.trim();
    const ok = await confirm({
      title: isEdit ? 'Save changes to this certificate?' : 'Create this certificate?',
      message: willNotify
        ? "It's active and has a holder email, so the holder will get a “certificate ready” notification."
        : 'This record is what the public verification flow checks against.',
      confirmLabel: isEdit ? 'Save certificate' : 'Create certificate'
    });
    if (!ok) return;

    setError('');
    try {
      if (isEdit) {
        await updateCertificate(id, form);
      } else {
        await saveCertificate(form);
      }
      navigate('/certificates');
    } catch (err) {
      setError(err.message);
    }
  }

  async function handleDelete() {
    const ok = await confirm({
      title: `Delete certificate ${form.certificate_number}?`,
      message: 'This removes the record the public verification flow checks against.',
      confirmLabel: 'Delete certificate'
    });
    if (!ok) return;
    try {
      await deleteCertificate(id);
      navigate('/certificates');
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div className="page">
      {confirmDialog}
      <div className="page-header">
        <div>
          <Link className="back-link" to="/certificates">
            ← Back to cert records
          </Link>
          <h2>{isEdit ? form.certificate_number || 'Edit certificate' : 'Create certificate'}</h2>
        </div>
        {isEdit ? (
          <button type="button" className="secondary-button danger-button" onClick={handleDelete}>
            Delete
          </button>
        ) : null}
      </div>

      {error ? <p className="error-banner">{error}</p> : null}

      {loading ? (
        <p className="muted-text">Loading…</p>
      ) : (
        <SectionCard
          title={isEdit ? 'Edit certificate' : 'Create certificate'}
          subtitle="Records checked by the app's public certificate-verification feature."
        >
          <form className="form" onSubmit={handleSubmit}>
            <div className="form-grid">
              <label>
                Certificate number
                <input
                  name="certificate_number"
                  value={form.certificate_number}
                  onChange={handleChange}
                  required
                />
              </label>
              <label>
                Type
                <select
                  name="certificate_type"
                  value={form.certificate_type}
                  onChange={handleChange}
                >
                  <option value="CSP">CSP</option>
                  <option value="CE">CE</option>
                  <option value="CP">CP</option>
                </select>
              </label>
            </div>
            <div className="form-grid">
              <label>
                Holder name
                <input name="holder_name" value={form.holder_name} onChange={handleChange} required />
              </label>
              <label>
                Organisation
                <input name="organisation" value={form.organisation} onChange={handleChange} />
              </label>
            </div>
            <label>
              Holder's account email (optional)
              <input
                type="email"
                name="holder_email"
                value={form.holder_email}
                onChange={handleChange}
                placeholder="Only needed to notify the holder when approved"
              />
            </label>
            <div className="form-grid">
              <label>
                Issue date
                <input
                  type="date"
                  name="issue_date"
                  value={form.issue_date}
                  onChange={handleChange}
                  required
                />
              </label>
              <label>
                Expiry date
                <input
                  type="date"
                  name="expiry_date"
                  value={form.expiry_date}
                  onChange={handleChange}
                  required
                />
              </label>
            </div>
            <label className="checkbox">
              <input
                type="checkbox"
                name="is_active"
                checked={form.is_active}
                onChange={handleChange}
              />
              <span>Active certificate</span>
            </label>
            <div className="button-row">
              <button type="submit">
                {isEdit ? 'Save certificate' : 'Create certificate'}
              </button>
              <button
                type="button"
                className="secondary-button"
                onClick={() => navigate('/certificates')}
              >
                Cancel
              </button>
            </div>
          </form>
        </SectionCard>
      )}
    </div>
  );
}
