import CampaignExtrasPanel from '../components/CampaignExtrasPanel';
import EventRegistrationsPanel from '../components/EventRegistrationsPanel';
import {
  deleteAdminNews,
  deleteCampaign,
  deleteEvent,
  deletePressRelease,
  getAdminNews,
  getAdminNewsItem,
  getCampaignDetail,
  getCampaigns,
  getEvent,
  getEvents,
  getPressRelease,
  getPressReleases,
  saveAdminNews,
  saveCampaign,
  saveEvent,
  savePressRelease,
  updateAdminNews,
  updateCampaign,
  updateEvent,
  updatePressRelease
} from '../services/api';

const NEWS_CATEGORIES = ['NEWS', 'ALERT', 'ADVISORY', 'NOTICE'];

// Send lat/lng as the literal string "null" when cleared, so the
// multipart serialiser doesn't drop the field and the backend can tell
// "clear the pin" apart from "field not touched".
function withCoords(form) {
  return {
    ...form,
    latitude: form.latitude == null ? 'null' : form.latitude,
    longitude: form.longitude == null ? 'null' : form.longitude
  };
}

// ---- Alerts (NewsArticle, category ALERT) ----
const alerts = {
  slug: 'alerts',
  basePath: '/alerts',
  singular: 'Alert',
  plural: 'Alerts',
  listSubtitle: 'Urgent alerts shown in the mobile app.',
  formSubtitle: 'Urgent alert content. Sending it pushes a notification to every app user.',
  publishedLabels: { on: 'Sent', off: 'Draft' },
  createLabel: 'Send alert',
  sendsPush: true,
  dateField: 'date_published',
  dateLabel: 'Published',
  searchFields: ['title', 'body'],
  fetchList: () => getAdminNews({ category: 'ALERT' }),
  fetchOne: (id) => getAdminNewsItem(id),
  create: (form) => saveAdminNews({ ...form, category: 'ALERT' }),
  update: (id, form) => updateAdminNews(id, { ...form, category: 'ALERT' }),
  remove: deleteAdminNews,
  emptyForm: { title: '', body: '', is_published: true, is_breaking: false },
  toForm: (item) => ({
    title: item.title,
    body: item.body,
    is_published: item.is_published,
    is_breaking: item.is_breaking
  }),
  fields: [
    { name: 'title', label: 'Title', type: 'text', required: true },
    { name: 'body', label: 'Body', type: 'textarea', rows: 8, required: true },
    { name: 'image', label: 'Image', type: 'image' },
    { name: 'is_published', label: 'Send push notification', type: 'checkbox' },
    { name: 'is_breaking', label: 'Also show in Breaking News', type: 'checkbox' }
  ]
};

// ---- Breaking news (NewsArticle, is_breaking true) ----
const breakingNews = {
  slug: 'breaking-news',
  basePath: '/breaking-news',
  singular: 'Breaking story',
  plural: 'Breaking news',
  listSubtitle: 'Stories flagged to stand out inside the mobile app.',
  formSubtitle: 'Breaking stories. Sending one pushes a notification to every app user.',
  publishedLabels: { on: 'Sent', off: 'Draft' },
  createLabel: 'Send breaking story',
  sendsPush: true,
  dateField: 'date_published',
  dateLabel: 'Published',
  searchFields: ['title', 'body', 'category'],
  fetchList: () => getAdminNews({ breaking: true }),
  fetchOne: (id) => getAdminNewsItem(id),
  create: (form) => saveAdminNews({ ...form, is_breaking: true }),
  update: (id, form) => updateAdminNews(id, { ...form, is_breaking: true }),
  remove: deleteAdminNews,
  emptyForm: { title: '', body: '', category: 'NOTICE', is_published: true, is_breaking: true },
  toForm: (item) => ({
    title: item.title,
    body: item.body,
    category: item.category,
    is_published: item.is_published,
    is_breaking: item.is_breaking
  }),
  fields: [
    { name: 'title', label: 'Title', type: 'text', required: true },
    {
      name: 'category',
      label: 'Category',
      type: 'select',
      options: NEWS_CATEGORIES.map((value) => ({ value, label: value }))
    },
    { name: 'body', label: 'Body', type: 'textarea', rows: 8, required: true },
    { name: 'image', label: 'Image', type: 'image' },
    { name: 'is_published', label: 'Send push notification', type: 'checkbox' }
  ]
};

// ---- Press releases ----
const pressReleases = {
  slug: 'press-releases',
  basePath: '/press-releases',
  singular: 'Press release',
  plural: 'Press releases',
  listSubtitle: 'Official releases and statements published to the app.',
  formSubtitle: 'Publish official releases and statements for the app.',
  dateField: 'date_published',
  dateLabel: 'Published',
  searchFields: ['title', 'body'],
  fetchList: getPressReleases,
  fetchOne: getPressRelease,
  create: savePressRelease,
  update: updatePressRelease,
  remove: deletePressRelease,
  emptyForm: { title: '', body: '', is_published: true },
  toForm: (item) => ({
    title: item.title,
    body: item.body,
    is_published: item.is_published
  }),
  fields: [
    { name: 'title', label: 'Title', type: 'text', required: true },
    { name: 'body', label: 'Body', type: 'textarea', rows: 10, required: true },
    { name: 'image', label: 'Image', type: 'image' },
    { name: 'is_published', label: 'Published', type: 'checkbox' }
  ]
};

// ---- Events ----
const events = {
  slug: 'events',
  basePath: '/events',
  singular: 'Event',
  plural: 'Events',
  listSubtitle: 'Events published to the mobile app.',
  formSubtitle: 'Publish events that should appear in the mobile app.',
  dateField: 'event_date',
  dateLabel: 'Event date',
  countField: 'total_registrations',
  countLabel: 'registered',
  searchFields: ['title', 'description', 'location'],
  fetchList: getEvents,
  fetchOne: getEvent,
  create: (form) => saveEvent(withCoords(form)),
  update: (id, form) => updateEvent(id, withCoords(form)),
  remove: deleteEvent,
  ExtraPanel: EventRegistrationsPanel,
  extraTabs: [{ key: 'registrations', label: 'Registrations' }],
  emptyForm: {
    title: '',
    description: '',
    location: '',
    latitude: null,
    longitude: null,
    event_date: '',
    end_date: '',
    start_time: '',
    end_time: '',
    is_published: true
  },
  toForm: (item) => ({
    title: item.title,
    description: item.description,
    location: item.location || '',
    latitude: item.latitude ?? null,
    longitude: item.longitude ?? null,
    event_date: item.event_date || '',
    end_date: item.end_date || '',
    start_time: item.start_time || '',
    end_time: item.end_time || '',
    is_published: item.is_published
  }),
  fields: [
    { name: 'title', label: 'Title', type: 'text', required: true },
    { name: 'location', label: 'Location (search or drop a pin)', type: 'location' },
    { name: 'description', label: 'Description', type: 'textarea', rows: 5, required: true },
    { name: 'event_date', label: 'Event date', type: 'date', required: true },
    { name: 'end_date', label: 'End date', type: 'date' },
    { name: 'start_time', label: 'Start time', type: 'time' },
    { name: 'end_time', label: 'End time', type: 'time' },
    { name: 'image', label: 'Image', type: 'image' },
    { name: 'is_published', label: 'Published', type: 'checkbox' }
  ]
};

// ---- NCSAM (Campaign, category NCSAM) ----
const ncsam = {
  slug: 'ncsam',
  basePath: '/ncsam',
  singular: 'NCSAM campaign',
  plural: 'NCSAM campaigns',
  listSubtitle: 'National Cyber Security Awareness Month campaigns (one per year).',
  formSubtitle:
    "This is what shows on the mobile app's NCSAM Overview tab. Include the year in the title, e.g. “NCSAM 2026”.",
  dateField: 'start_date',
  dateLabel: 'Starts',
  countField: 'registration_count',
  countLabel: 'registered',
  searchFields: ['title', 'description', 'target_audience'],
  fetchList: async () => {
    const items = await getCampaigns();
    return items.filter((item) => item.category === 'NCSAM');
  },
  fetchOne: async (id) => (await getCampaignDetail(id)).item,
  create: (form) => saveCampaign({ ...withCoords(form), category: 'NCSAM' }),
  update: (id, form) => updateCampaign(id, { ...withCoords(form), category: 'NCSAM' }),
  remove: deleteCampaign,
  ExtraPanel: CampaignExtrasPanel,
  extraTabs: [
    { key: 'registrations', label: 'Registrations' },
    { key: 'schedule', label: 'Schedule' },
    { key: 'speakers', label: 'Speakers' },
    { key: 'gallery', label: 'Gallery' }
  ],
  emptyForm: {
    title: '',
    description: '',
    start_date: '',
    end_date: '',
    target_audience: '',
    location: '',
    latitude: null,
    longitude: null,
    is_published: true
  },
  toForm: (item) => ({
    title: item.title,
    description: item.description,
    start_date: item.start_date || '',
    end_date: item.end_date || '',
    target_audience: item.target_audience || '',
    location: item.location || '',
    latitude: item.latitude ?? null,
    longitude: item.longitude ?? null,
    is_published: item.is_published
  }),
  fields: [
    { name: 'title', label: 'Title (include the year, e.g. “NCSAM 2026”)', type: 'text', required: true },
    { name: 'description', label: 'Description', type: 'textarea', rows: 5, required: true },
    { name: 'start_date', label: 'Start date', type: 'date', required: true },
    { name: 'end_date', label: 'End date', type: 'date' },
    { name: 'target_audience', label: 'Target audience', type: 'text' },
    { name: 'location', label: 'Venue (search or drop a pin)', type: 'location' },
    { name: 'image', label: 'Image', type: 'image' },
    { name: 'is_published', label: 'Published', type: 'checkbox' }
  ]
};

export const CONTENT_CONFIGS = { alerts, breakingNews, pressReleases, events, ncsam };
