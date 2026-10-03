import { API_BASE_URL } from '../config';

const ADMIN_KEY = 'csa_admin_profile';
const LEGACY_TOKEN_KEY = 'csa_admin_access_token';

// Fired when the server no longer accepts the session, so the app can drop
// back to the login page from anywhere.
export const SESSION_EXPIRED_EVENT = 'csa-admin-session-expired';

// The login tokens used to be kept in localStorage, readable by any script
// on the page. They now live in HttpOnly cookies the browser manages by
// itself, so JavaScript never sees them. Purge any copy left from before.
try {
  window.localStorage.removeItem(LEGACY_TOKEN_KEY);
} catch {
  // storage unavailable - nothing to purge
}

function buildUrl(path) {
  return `${API_BASE_URL}${path}`;
}

// Only the non-secret profile (name, roles) is kept, to draw the right menu
// before the first request. The server enforces permissions on its own.
export function getStoredAdmin() {
  try {
    const raw = window.localStorage.getItem(ADMIN_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

export function clearAdminSession() {
  window.localStorage.removeItem(ADMIN_KEY);
}

async function parseResponse(response) {
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.error || data.detail || 'Request failed.');
  }
  return data;
}

// Marks every request as coming from this app. Together with SameSite
// cookies this is what stops another website from making a signed-in
// staff member's browser change data (cross-site request forgery).
const REQUEST_HEADERS = { 'X-CSA-Admin': '1' };
const AUTH_PATHS = ['/api/admin/login/', '/api/admin/refresh/', '/api/admin/logout/'];

let refreshInFlight = null;

function refreshSession() {
  if (!refreshInFlight) {
    refreshInFlight = fetch(buildUrl('/api/admin/refresh/'), {
      method: 'POST',
      headers: REQUEST_HEADERS,
      credentials: 'same-origin'
    })
      .then((response) => response.ok)
      .catch(() => false)
      .finally(() => {
        refreshInFlight = null;
      });
  }
  return refreshInFlight;
}

// fetch() plus: the safety header, and one silent session refresh when the
// short-lived access cookie has expired.
async function apiFetch(path, options = {}) {
  const send = () => {
    const headers = new Headers(options.headers || {});
    Object.entries(REQUEST_HEADERS).forEach(([key, value]) => headers.set(key, value));
    return fetch(buildUrl(path), { ...options, headers, credentials: 'same-origin' });
  };

  let response = await send();

  if (response.status === 401 && !AUTH_PATHS.includes(path)) {
    if (await refreshSession()) {
      response = await send();
    }
    if (response.status === 401) {
      clearAdminSession();
      window.dispatchEvent(new Event(SESSION_EXPIRED_EVENT));
    }
  }

  return response;
}

async function request(path, options = {}) {
  const response = await apiFetch(path, options);
  return parseResponse(response);
}

function toFormData(payload) {
  const formData = new FormData();

  Object.entries(payload).forEach(([key, value]) => {
    if (value === undefined || value === null || value === '') {
      return;
    }

    if (value instanceof File) {
      formData.append(key, value);
      return;
    }

    formData.append(key, String(value));
  });

  return formData;
}

export async function loginAdmin(credentials) {
  const data = await request('/api/admin/login/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(credentials)
  });

  window.localStorage.setItem(ADMIN_KEY, JSON.stringify(data.admin));
  return data;
}

export async function logoutAdmin() {
  try {
    await apiFetch('/api/admin/logout/', { method: 'POST' });
  } catch {
    // offline - the cookies expire on their own
  }
  clearAdminSession();
}

export async function getDashboardSummary() {
  return request('/api/admin/dashboard/');
}

export async function getCertificatesDashboard() {
  return request('/api/incidents/admin/dashboard/certificates/');
}

export async function getCertDashboard() {
  return request('/api/incidents/admin/dashboard/cert/');
}

export async function getContentDashboard() {
  return request('/api/content/admin/dashboard/content/');
}

export async function getItDashboard() {
  return request('/api/admin/dashboard/it/');
}

export async function getStaff() {
  const data = await request('/api/admin/staff/');
  return data.items || [];
}

export async function createStaff(payload) {
  const data = await request('/api/admin/staff/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  return data.item;
}

export async function updateStaff(userId, payload) {
  const data = await request(`/api/admin/staff/${userId}/`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  return data.item;
}

export async function getUsers() {
  const data = await request('/api/admin/users/');
  return data.users || [];
}

export async function getUserDetail(userId) {
  const data = await request(`/api/admin/users/${userId}/`);
  return data.user;
}

export async function getReports(status) {
  const suffix = status && status !== 'ALL' ? `?status=${encodeURIComponent(status)}` : '';
  const data = await request(`/api/incidents/admin/reports/${suffix}`);
  return data.reports || [];
}

export async function getReport(referenceNumber) {
  const path = `/api/incidents/admin/reports/${encodeURIComponent(referenceNumber)}/`;
  const data = await request(path);
  return data.report;
}

export async function updateReportStatus(referenceNumber, status) {
  const path = `/api/incidents/admin/reports/${referenceNumber}/`;
  const data = await request(path, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ status })
  });

  return data.report;
}

// The ordered list of report statuses (Pending, Under Review,
// Resolved, plus anything CERT has added) — position-ordered, so
// rendering it in the order returned is always correct.
export async function getReportStatuses() {
  const data = await request('/api/incidents/admin/report-statuses/');
  return data.statuses || [];
}

// Adds a new status. `insertAfter` is the key of an existing status to
// place the new one right after (omit to insert at the very start) —
// the backend renumbers everything else so the ordering stays clean.
export async function createReportStatus({ key, label, color, insertAfter }) {
  const data = await request('/api/incidents/admin/report-statuses/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ key, label, color, insert_after: insertAfter || '' })
  });

  return data.status;
}

export async function getAdminNews(filters = {}) {
  const params = new URLSearchParams();

  if (filters.category) {
    params.set('category', filters.category);
  }

  if (typeof filters.breaking === 'boolean') {
    params.set('breaking', String(filters.breaking));
  }

  const query = params.toString();
  const suffix = query ? `?${query}` : '';
  const data = await request(`/api/content/admin/news/${suffix}`);
  return data.items || [];
}

export async function saveAdminNews(payload) {
  const data = await request('/api/content/admin/news/', {
    method: 'POST',
    body: toFormData(payload)
  });

  return data.item;
}

export async function getAdminNewsItem(id) {
  const data = await request(`/api/content/admin/news/${id}/`);
  return data.item;
}

export async function updateAdminNews(id, payload) {
  const data = await request(`/api/content/admin/news/${id}/`, {
    method: 'PUT',
    body: toFormData(payload)
  });

  return data.item;
}

export async function deleteAdminNews(id) {
  const response = await apiFetch(`/api/content/admin/news/${id}/`, {
    method: 'DELETE'
  });

  if (!response.ok && response.status !== 204) {
    const data = await response.json().catch(() => ({}));
    throw new Error(data.error || 'Delete failed.');
  }
}

async function listItems(path) {
  const data = await request(path);
  return data.items || [];
}

async function saveItem(path, payload) {
  const data = await request(path, {
    method: 'POST',
    body: toFormData(payload)
  });
  return data.item;
}

async function updateItem(path, payload) {
  const data = await request(path, {
    method: 'PUT',
    body: toFormData(payload)
  });
  return data.item;
}

async function deleteItem(path) {
  const response = await apiFetch(path, {
    method: 'DELETE'
  });

  if (!response.ok && response.status !== 204) {
    const data = await response.json().catch(() => ({}));
    throw new Error(data.error || 'Delete failed.');
  }
}

export async function getEvents() {
  return listItems('/api/content/admin/events/');
}

export async function getEvent(id) {
  const data = await request(`/api/content/admin/events/${id}/`);
  return data.item;
}

export async function getEventRegistrations(eventId) {
  const path = `/api/content/admin/events/${eventId}/registrations/`;
  const data = await request(path);
  return data.registrations || [];
}

// ============================================================
// Receptionist check-in. Sends the code a receptionist types in
// (e.g. "CSA-P9X3WA") to the backend, which confirms it belongs
// to a registration for THIS event and marks that person
// checked in.
// Returns { item: {...registration with check-in fields...},
//           already_checked_in: bool, message: string }
// ============================================================
export async function checkInRegistration(eventId, checkInCode) {
  const path = `/api/content/admin/events/${eventId}/check-in/`;
  return request(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ check_in_code: checkInCode })
  });
}

export async function saveEvent(payload) {
  return saveItem('/api/content/admin/events/', payload);
}

export async function updateEvent(id, payload) {
  return updateItem(`/api/content/admin/events/${id}/`, payload);
}

export async function deleteEvent(id) {
  return deleteItem(`/api/content/admin/events/${id}/`);
}

export async function getCampaigns() {
  return listItems('/api/content/admin/campaigns/');
}

export async function getCampaignDetail(campaignId) {
  return request(`/api/content/admin/campaigns/${campaignId}/`);
}

export async function getCampaignRegistrations(campaignId) {
  const path = `/api/content/admin/campaigns/${campaignId}/registrations/`;
  const data = await request(path);
  return data.registrations || [];
}

export async function checkInCampaignRegistration(campaignId, checkInCode) {
  const path = `/api/content/admin/campaigns/${campaignId}/check-in/`;
  return request(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ check_in_code: checkInCode })
  });
}

export async function saveCampaign(payload) {
  return saveItem('/api/content/admin/campaigns/', payload);
}

export async function updateCampaign(id, payload) {
  return updateItem(`/api/content/admin/campaigns/${id}/`, payload);
}

export async function deleteCampaign(id) {
  return deleteItem(`/api/content/admin/campaigns/${id}/`);
}

export async function createCampaignGallery(campaignId, payload) {
  const path = `/api/content/admin/campaigns/${campaignId}/gallery/`;
  return saveItem(path, payload);
}

export async function updateCampaignGallery(galleryId, payload) {
  const path = `/api/content/admin/campaigns/gallery/${galleryId}/`;
  return updateItem(path, payload);
}

export async function deleteCampaignGallery(galleryId) {
  const path = `/api/content/admin/campaigns/gallery/${galleryId}/`;
  return deleteItem(path);
}

export async function createCampaignSchedule(campaignId, payload) {
  const path = `/api/content/admin/campaigns/${campaignId}/schedule/`;
  const data = await request(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  return data.item;
}

export async function updateCampaignSchedule(scheduleId, payload) {
  const path = `/api/content/admin/campaigns/schedule/${scheduleId}/`;
  const data = await request(path, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  return data.item;
}

export async function deleteCampaignSchedule(scheduleId) {
  const path = `/api/content/admin/campaigns/schedule/${scheduleId}/`;
  return deleteItem(path);
}

export async function createCampaignSpeaker(campaignId, payload) {
  const path = `/api/content/admin/campaigns/${campaignId}/speakers/`;
  return saveItem(path, payload);
}

export async function updateCampaignSpeaker(speakerId, payload) {
  const path = `/api/content/admin/campaigns/speakers/${speakerId}/`;
  return updateItem(path, payload);
}

export async function deleteCampaignSpeaker(speakerId) {
  const path = `/api/content/admin/campaigns/speakers/${speakerId}/`;
  return deleteItem(path);
}

export async function createCampaignRelatedNews(campaignId, articleId) {
  const path = `/api/content/admin/campaigns/${campaignId}/related-news/`;
  const data = await request(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ article_id: articleId })
  });
  return data.item;
}

export async function deleteCampaignRelatedNews(id) {
  const path = `/api/content/admin/campaigns/related-news/${id}/`;
  return deleteItem(path);
}

export async function getPressReleases() {
  return listItems('/api/content/admin/press-releases/');
}

export async function getPressRelease(id) {
  const data = await request(`/api/content/admin/press-releases/${id}/`);
  return data.item;
}

export async function savePressRelease(payload) {
  return saveItem('/api/content/admin/press-releases/', payload);
}

export async function updatePressRelease(id, payload) {
  const path = `/api/content/admin/press-releases/${id}/`;
  return updateItem(path, payload);
}

export async function deletePressRelease(id) {
  return deleteItem(`/api/content/admin/press-releases/${id}/`);
}

export async function getAboutPage() {
  const data = await request('/api/content/admin/content/about/');
  return data.item;
}

export async function updateAboutPage(payload) {
  return updateItem('/api/content/admin/content/about/', payload);
}

export async function getContactPage() {
  const data = await request('/api/content/admin/content/contact/');
  return data.item;
}

export async function updateContactPage(payload) {
  const data = await request('/api/content/admin/content/contact/', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  return data.item;
}

export async function getFeedback() {
  const data = await request('/api/admin/feedback/');
  return data.feedback || [];
}

export async function getContactMessages() {
  const data = await request('/api/admin/messages/');
  return data.messages || [];
}

export async function updateFeedback(id, payload) {
  const data = await request('/api/admin/feedback/', {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ id, ...payload })
  });
  return data.feedback || [];
}

export async function updateContactMessage(id, payload) {
  const data = await request('/api/admin/messages/', {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ id, ...payload })
  });
  return data.messages || [];
}

export async function updateUser(userId, payload) {
  const data = await request(`/api/admin/users/${userId}/`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  return data.user;
}

export async function getCertificates() {
  return listItems('/api/incidents/admin/certificates/');
}

export async function getCertificate(id) {
  const data = await request(`/api/incidents/admin/certificates/${id}/`);
  return data.item;
}

export async function saveCertificate(payload) {
  const data = await request('/api/incidents/admin/certificates/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  return data.item;
}

export async function updateCertificate(id, payload) {
  const path = `/api/incidents/admin/certificates/${id}/`;
  const data = await request(path, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  return data.item;
}

export async function deleteCertificate(id) {
  return deleteItem(`/api/incidents/admin/certificates/${id}/`);
}