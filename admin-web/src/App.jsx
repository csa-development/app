import { useState } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import Layout from './components/Layout';
import RoleRoute from './components/RoleRoute';
import CampaignDetailPage from './pages/CampaignDetailPage';
import CampaignPublishPage from './pages/CampaignPublishPage';
import CampaignsListPage from './pages/CampaignsListPage';
import AboutCsaPage from './pages/AboutCsaPage';
import CertDashboardPage from './pages/CertDashboardPage';
import CertificateFormPage from './pages/CertificateFormPage';
import CertificatesPage from './pages/CertificatesPage';
import ContactCsaPage from './pages/ContactCsaPage';
import ContentFormPage from './pages/ContentFormPage';
import ContentListPage from './pages/ContentListPage';
import DashboardPage from './pages/DashboardPage';
import FeedbackCategoryPage from './pages/FeedbackCategoryPage';
import ItDashboardPage from './pages/ItDashboardPage';
import LoginPage from './pages/LoginPage';
import MessagesPage from './pages/MessagesPage';
import RatingsOverviewPage from './pages/RatingsOverviewPage';
import RatingsStreamPage from './pages/RatingsStreamPage';
import ReportDetailPage from './pages/ReportDetailPage';
import ReportsPage from './pages/ReportsPage';
import StaffPage from './pages/StaffPage';
import UserProfilePage from './pages/UserProfilePage';
import UsersPage from './pages/UsersPage';
import { CERT, COMMS, IT, LECO, SUPERADMIN, roleHomePath } from './roleAccess';
import { clearAdminSession, getStoredAdmin, loginAdmin } from './services/api';

export default function App() {
  const [admin, setAdmin] = useState(getStoredAdmin());
  const [authError, setAuthError] = useState('');
  const [authLoading, setAuthLoading] = useState(false);

  async function handleLogin(credentials) {
    setAuthLoading(true);
    setAuthError('');

    try {
      const session = await loginAdmin(credentials);
      setAdmin(session.admin);
    } catch (error) {
      setAuthError(error.message);
    } finally {
      setAuthLoading(false);
    }
  }

  function handleLogout() {
    clearAdminSession();
    setAdmin(null);
  }

  if (!admin) {
    return (
      <LoginPage
        onLogin={handleLogin}
        loading={authLoading}
        error={authError}
      />
    );
  }

  const home = roleHomePath(admin);
  if (!home) {
    return (
      <div className="login-shell">
        <section className="login-card">
          <img src="/csalogo.png" alt="CSA logo" className="login-logo" />
          <p className="eyebrow">CSA Mobile</p>
          <h1>No role assigned</h1>
          <p className="login-copy">
            Your account doesn&apos;t have a role assigned yet. Ask a SUPERADMIN to assign one.
          </p>
          <button type="button" className="secondary-button sidebar-button" onClick={handleLogout}>
            Sign out
          </button>
        </section>
      </div>
    );
  }

  // List → add → detail(edit) routes for a config-driven content type.
  const contentRoutes = (base, key, roles) => [
    <Route
      key={base}
      path={base}
      element={
        <RoleRoute admin={admin} roles={roles}>
          <ContentListPage configKey={key} />
        </RoleRoute>
      }
    />,
    <Route
      key={`${base}/new`}
      path={`${base}/new`}
      element={
        <RoleRoute admin={admin} roles={roles}>
          <ContentFormPage configKey={key} />
        </RoleRoute>
      }
    />,
    <Route
      key={`${base}/:id`}
      path={`${base}/:id`}
      element={
        <RoleRoute admin={admin} roles={roles}>
          <ContentFormPage configKey={key} />
        </RoleRoute>
      }
    />
  ];

  return (
    <Layout admin={admin} onLogout={handleLogout}>
      <Routes>
        <Route path="/" element={<Navigate to={home} replace />} />
        <Route
          path="/dashboard"
          element={
            <RoleRoute admin={admin} roles={[SUPERADMIN]}>
              <DashboardPage />
            </RoleRoute>
          }
        />
        <Route
          path="/dashboard/cert"
          element={
            <RoleRoute admin={admin} roles={[CERT]}>
              <CertDashboardPage />
            </RoleRoute>
          }
        />
        <Route
          path="/dashboard/it"
          element={
            <RoleRoute admin={admin} roles={[IT]}>
              <ItDashboardPage />
            </RoleRoute>
          }
        />
        {contentRoutes('/alerts', 'alerts', [IT, COMMS])}
        {contentRoutes('/breaking-news', 'breakingNews', [IT, COMMS])}
        {contentRoutes('/events', 'events', [IT, COMMS])}
        <Route
          path="/campaigns"
          element={
            <RoleRoute admin={admin} roles={[IT]}>
              <CampaignsListPage />
            </RoleRoute>
          }
        />
        <Route
          path="/campaigns/publish"
          element={
            <RoleRoute admin={admin} roles={[IT]}>
              <CampaignPublishPage />
            </RoleRoute>
          }
        />
        <Route
          path="/campaigns/:id"
          element={
            <RoleRoute admin={admin} roles={[IT]}>
              <CampaignDetailPage />
            </RoleRoute>
          }
        />
        {contentRoutes('/ncsam', 'ncsam', [IT, COMMS])}
        {contentRoutes('/press-releases', 'pressReleases', [IT, COMMS])}
        <Route
          path="/certificates"
          element={
            <RoleRoute admin={admin} roles={[IT, LECO]}>
              <CertificatesPage />
            </RoleRoute>
          }
        />
        <Route
          path="/certificates/new"
          element={
            <RoleRoute admin={admin} roles={[IT, LECO]}>
              <CertificateFormPage />
            </RoleRoute>
          }
        />
        <Route
          path="/certificates/:id"
          element={
            <RoleRoute admin={admin} roles={[IT, LECO]}>
              <CertificateFormPage />
            </RoleRoute>
          }
        />
        <Route
          path="/users"
          element={
            <RoleRoute admin={admin} roles={[IT]}>
              <UsersPage />
            </RoleRoute>
          }
        />
        <Route
          path="/users/:id"
          element={
            <RoleRoute admin={admin} roles={[IT]}>
              <UserProfilePage />
            </RoleRoute>
          }
        />
        <Route
          path="/reports"
          element={
            <RoleRoute admin={admin} roles={[CERT]}>
              <ReportsPage />
            </RoleRoute>
          }
        />
        <Route
          path="/reports/:referenceNumber"
          element={
            <RoleRoute admin={admin} roles={[CERT]}>
              <ReportDetailPage />
            </RoleRoute>
          }
        />
        <Route
          path="/site-content"
          element={
            <RoleRoute admin={admin} roles={[IT]}>
              <AboutCsaPage />
            </RoleRoute>
          }
        />
        <Route
          path="/site-content/contact"
          element={
            <RoleRoute admin={admin} roles={[IT]}>
              <ContactCsaPage />
            </RoleRoute>
          }
        />
        <Route
          path="/feedback"
          element={
            <RoleRoute admin={admin} roles={[IT]}>
              <FeedbackCategoryPage
                category="BUG_REPORT"
                title="Bug Reports"
                subtitle="Problems users have reported from inside the app."
                emptyLabel="No bug reports match the current filter."
              />
            </RoleRoute>
          }
        />
        <Route
          path="/feedback/suggestions"
          element={
            <RoleRoute admin={admin} roles={[IT]}>
              <FeedbackCategoryPage
                category="SUGGESTION"
                title="Suggestions"
                subtitle="Ideas and feature requests users have sent in."
                emptyLabel="No suggestions match the current filter."
              />
            </RoleRoute>
          }
        />
        <Route
          path="/feedback/questions"
          element={
            <RoleRoute admin={admin} roles={[IT]}>
              <FeedbackCategoryPage
                category="QUESTION"
                title="Questions"
                subtitle="Questions users have asked from inside the app."
                emptyLabel="No questions match the current filter."
              />
            </RoleRoute>
          }
        />
        <Route
          path="/feedback/compliments"
          element={
            <RoleRoute admin={admin} roles={[IT]}>
              <FeedbackCategoryPage
                category="COMPLIMENT"
                title="Compliments"
                subtitle="Positive feedback users have sent in."
                emptyLabel="No compliments match the current filter."
              />
            </RoleRoute>
          }
        />
        <Route
          path="/ratings"
          element={
            <RoleRoute admin={admin} roles={[IT]}>
              <RatingsOverviewPage />
            </RoleRoute>
          }
        />
        <Route
          path="/ratings/stream"
          element={
            <RoleRoute admin={admin} roles={[IT]}>
              <RatingsStreamPage />
            </RoleRoute>
          }
        />
        <Route
          path="/messages"
          element={
            <RoleRoute admin={admin} roles={[IT, SUPERADMIN]}>
              <MessagesPage />
            </RoleRoute>
          }
        />
        <Route
          path="/staff"
          element={
            <RoleRoute admin={admin} roles={[SUPERADMIN]}>
              <StaffPage />
            </RoleRoute>
          }
        />
        <Route path="*" element={<Navigate to={home} replace />} />
      </Routes>
    </Layout>
  );
}
