import { useCallback, useEffect, useState } from 'react';
import { Link, useLocation, useParams } from 'react-router-dom';
import SectionCard from '../components/SectionCard';
import useConfirm from '../hooks/useConfirm';
import { getReport, getReportStatuses, updateReportStatus } from '../services/api';

export default function ReportDetailPage() {
  const { referenceNumber } = useParams();
  const location = useLocation();

  const [report, setReport] = useState(location.state?.report || null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(!location.state?.report);
  const [confirm, confirmDialog] = useConfirm();
  // Position-ordered list of statuses — whatever CERT has configured,
  // not a hardcoded 3-value list, so a status added from the Reports
  // page (or another admin) shows up here without a code change.
  const [statuses, setStatuses] = useState([]);

  const loadReport = useCallback(() => {
    return getReport(referenceNumber)
      .then((data) => {
        setReport(data);
        setError('');
      })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [referenceNumber]);

  useEffect(() => {
    loadReport();
  }, [loadReport]);

  useEffect(() => {
    getReportStatuses()
      .then(setStatuses)
      .catch(() => {
        // Non-fatal — the page still works with an empty status list,
        // it just can't render the timeline/dropdown until this loads.
      });
  }, []);

  const statusLabel = (key) => statuses.find((s) => s.key === key)?.label || key;
  const statusOrder = (key) => statuses.findIndex((s) => s.key === key);

  const VIDEO_EXTENSIONS = ['mp4', 'mov', 'webm', 'mkv', 'avi', '3gp'];
  const isVideoEvidence = (filename) => {
    const ext = filename?.split('.').pop()?.toLowerCase();
    return VIDEO_EXTENSIONS.includes(ext);
  };

  async function changeStatus(newStatus) {
    if (!report || newStatus === report.status) return;

    const ok = await confirm({
      title: `Set this report to “${statusLabel(newStatus)}”?`,
      message: 'The person who filed the report will get a push notification about this change.',
      confirmLabel: 'Update status'
    });
    if (!ok) return;

    try {
      const updated = await updateReportStatus(referenceNumber, newStatus);
      setReport(updated);
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div className="page">
      {confirmDialog}
      <div className="page-header">
        <div>
          <Link className="back-link" to="/reports">
            ← Back to reports
          </Link>
          <h2>{report ? `Report ${report.reference_number}` : 'Incident details'}</h2>
        </div>
      </div>

      {error ? <p className="error-banner">{error}</p> : null}

      {loading ? (
        <p className="muted-text">Loading report…</p>
      ) : !report ? (
        <p className="muted-text">This report could not be found.</p>
      ) : (
        <div className="detail-columns">
        <SectionCard
          title="Incident details"
          subtitle="Full report details, including reporter contact information."
        >
          <div className="detail-stack">
            <div className="coverage-grid">
              <div className="coverage-card">
                <strong>{report.incident_type}</strong>
                <span>Incident type</span>
              </div>
              <div className="coverage-card">
                <strong>{report.platform}</strong>
                <span>Platform</span>
              </div>
              <div className="coverage-card">
                <strong>{report.location || 'Not specified'}</strong>
                <span>Location</span>
              </div>
              <div className="coverage-card">
                <strong>
                  {report.date_of_incident
                    ? new Date(report.date_of_incident).toLocaleDateString()
                    : 'Not specified'}
                </strong>
                <span>Date of incident</span>
              </div>
              {report.latitude != null && report.longitude != null ? (
                <div className="coverage-card">
                  <strong>
                    <a
                      href={`https://www.openstreetmap.org/?mlat=${report.latitude}&mlon=${report.longitude}#map=17/${report.latitude}/${report.longitude}`}
                      target="_blank"
                      rel="noreferrer"
                    >
                      View pinned location
                    </a>
                  </strong>
                  <span>
                    {report.latitude.toFixed(5)}, {report.longitude.toFixed(5)}
                  </span>
                </div>
              ) : null}
            </div>

            <div className="detail-block">
              <h3>Reporter contact</h3>
              <div className="coverage-grid">
                <div className="coverage-card">
                  <strong>{report.reporter_name || 'Not provided'}</strong>
                  <span>Name</span>
                </div>
                <div className="coverage-card">
                  <strong>{report.reporter_phone || 'Not provided'}</strong>
                  <span>Phone number</span>
                </div>
                <div className="coverage-card">
                  <strong>{report.user?.email || 'Not provided'}</strong>
                  <span>Email</span>
                </div>
                <div className="coverage-card">
                  <strong>{report.user?.name || 'Not linked'}</strong>
                  <span>Account name</span>
                </div>
              </div>
              {report.reporting_for_someone ? (
                <p className="muted-text">
                  Filed on behalf of someone else
                  {report.relationship_to_victim ? ` (${report.relationship_to_victim})` : ''}.
                </p>
              ) : null}
            </div>

            <div className="detail-block">
              <h3>Description</h3>
              <p>{report.description || 'No description provided.'}</p>
            </div>

            {report.evidence_description || report.evidence_url ? (
              <div className="detail-block">
                <h3>Evidence</h3>
                {report.evidence_description ? <p>{report.evidence_description}</p> : null}
                {report.evidence_url ? (
                  isVideoEvidence(report.evidence_filename) ? (
                    <>
                      <video
                        src={report.evidence_url}
                        controls
                        preload="metadata"
                        playsInline
                        className="evidence-preview"
                        style={{ maxWidth: '100%', maxHeight: 360, borderRadius: 8 }}
                      >
                        Your browser can&apos;t play this video here.
                      </video>
                      <p className="muted-text">
                        <a href={report.evidence_url} download target="_blank" rel="noreferrer">
                          Download video
                        </a>
                      </p>
                    </>
                  ) : (
                    <a href={report.evidence_url} target="_blank" rel="noreferrer">
                      <img
                        src={report.evidence_url}
                        alt="Submitted evidence"
                        className="evidence-preview"
                        style={{ maxWidth: '100%', maxHeight: 360, borderRadius: 8 }}
                        onError={(event) => {
                          // Not actually an image the browser can decode (e.g. an
                          // unrecognized video type) — fall back to a plain link
                          // instead of showing a broken-image icon.
                          event.target.style.display = 'none';
                          event.target.nextSibling?.classList.remove('hidden');
                        }}
                      />
                      <span className="hidden">Open evidence file</span>
                    </a>
                  )
                ) : null}
              </div>
            ) : null}
          </div>
        </SectionCard>

        <SectionCard title="Status" subtitle="Update where this report sits in the workflow.">
          <div className="detail-stack">
            <ol className="status-steps">
              {statuses.map((step) => {
                const state =
                  step.key === report.status
                    ? 'current'
                    : statusOrder(step.key) < statusOrder(report.status)
                    ? 'done'
                    : 'upcoming';
                return (
                  <li key={step.key} className={`status-step status-step-${state}`}>
                    <span className="status-step-dot" />
                    <span>{step.label}</span>
                  </li>
                );
              })}
            </ol>

            <div className="detail-block">
              <h3>Change status</h3>
              <select value={report.status} onChange={(event) => changeStatus(event.target.value)}>
                {statuses.map((s) => (
                  <option key={s.key} value={s.key}>{s.label}</option>
                ))}
              </select>
            </div>

            <div className="detail-block">
              <h3>Timeline</h3>
              <p className="muted-text">
                Created {new Date(report.created_at).toLocaleString()}
              </p>
              <p className="muted-text">
                Last updated {new Date(report.updated_at).toLocaleString()}
              </p>
            </div>
          </div>
        </SectionCard>
        </div>
      )}
    </div>
  );
}
