import { useEffect, useState } from 'react';
import { NavLink, useLocation } from 'react-router-dom';
import { CERT, COMMS, IT, LECO, SUPERADMIN, hasRole } from '../roleAccess';

const THEME_KEY = 'csa_admin_theme';

function useTheme() {
  const [theme, setTheme] = useState(() => {
    try {
      return localStorage.getItem(THEME_KEY) || 'system';
    } catch {
      return 'system';
    }
  });

  useEffect(() => {
    const root = document.documentElement;
    if (theme === 'system') {
      root.removeAttribute('data-theme');
    } else {
      root.setAttribute('data-theme', theme);
    }
    try {
      localStorage.setItem(THEME_KEY, theme);
    } catch {
      /* ignore */
    }
  }, [theme]);

  const isDark =
    theme === 'dark' ||
    (theme === 'system' &&
      window.matchMedia &&
      window.matchMedia('(prefers-color-scheme: dark)').matches);

  return { isDark, toggle: () => setTheme(isDark ? 'light' : 'dark') };
}

const navItems = [
  { to: '/dashboard', label: 'Dashboard', roles: [SUPERADMIN] },
  { to: '/dashboard/cert', label: 'CERT Dashboard', roles: [CERT] },
  { to: '/dashboard/it', label: 'IT Dashboard', roles: [IT] },
  { to: '/alerts', label: 'Alerts', roles: [IT, COMMS] },
  { to: '/breaking-news', label: 'Breaking News', roles: [IT, COMMS] },
  { to: '/events', label: 'Events', roles: [IT, COMMS] },
  {
    to: '/campaigns',
    label: 'Campaigns',
    roles: [IT],
    subNav: [
      { to: '/campaigns', label: 'All Campaigns' },
      { to: '/campaigns/publish', label: 'Publish Campaign' }
    ]
  },
  { to: '/ncsam', label: 'NCSAM', roles: [IT, COMMS] },
  { to: '/press-releases', label: 'Press Releases', roles: [IT, COMMS] },
  {
    to: '/site-content',
    label: 'Site Content',
    roles: [IT],
    subNav: [
      { to: '/site-content', label: 'About Us' },
      { to: '/site-content/contact', label: 'Contact Us' }
    ]
  },
  {
    to: '/certificates',
    label: 'Certificates',
    roles: [IT, LECO],
    subNav: [
      { to: '/certificates', label: 'Cert Records' },
      { to: '/certificates/new', label: 'Create Cert' }
    ]
  },
  {
    to: '/users',
    label: 'Users',
    roles: [IT],
    subNav: [{ to: '/users', label: 'User Activity' }]
  },
  { to: '/reports', label: 'Reports', roles: [CERT] },
  {
    to: '/feedback',
    label: 'Feedback',
    roles: [IT],
    subNav: [
      { to: '/feedback', label: 'Bug Reports' },
      { to: '/feedback/suggestions', label: 'Suggestions' },
      { to: '/feedback/questions', label: 'Questions' },
      { to: '/feedback/compliments', label: 'Compliments' }
    ]
  },
  {
    to: '/ratings',
    label: 'Ratings',
    roles: [IT],
    subNav: [
      { to: '/ratings', label: 'App Rating Review' },
      { to: '/ratings/stream', label: 'Ratings Stream' }
    ]
  },
  { to: '/messages', label: 'Messages', roles: [IT, SUPERADMIN] },
  { to: '/staff', label: 'Staff & Roles', roles: [SUPERADMIN] }
];

export default function Layout({ children, admin, onLogout }) {
  const location = useLocation();
  const visibleNavItems = navItems.filter((item) => hasRole(admin, item.roles));
  const { isDark, toggle } = useTheme();

  const pageTitles = {
    '/dashboard': 'Operations Dashboard',
    '/dashboard/cert': 'CERT Incident Dashboard',
    '/dashboard/it': 'IT Dashboard',
    '/alerts': 'Alert Publishing',
    '/breaking-news': 'Breaking News Desk',
    '/events': 'Events Publishing',
    '/campaigns': 'Campaigns Publishing',
    '/ncsam': 'NCSAM',
    '/press-releases': 'Press Release Desk',
    '/site-content': 'Site Content',
    '/certificates': 'Certificate Registry',
    '/users': 'User Activity',
    '/reports': 'Incident Reports',
    '/ratings': 'App Ratings',
    '/messages': 'Contact Messages',
    '/staff': 'Staff & Role Management'
  };

  const contentSections = {
    '/alerts': 'Alerts',
    '/breaking-news': 'Breaking News',
    '/events': 'Events',
    '/press-releases': 'Press Releases',
    '/ncsam': 'NCSAM'
  };

  function getBreadcrumb(pathname) {
    if (pathname === '/campaigns') return { section: 'Campaigns', page: 'All Campaigns' };
    if (pathname === '/campaigns/publish') return { section: 'Campaigns', page: 'Publish Campaign' };
    if (pathname.startsWith('/campaigns/')) return { section: 'Campaigns', page: 'Campaign Details' };
    if (pathname === '/site-content') return { section: 'Site Content', page: 'About Us' };
    if (pathname === '/site-content/contact') return { section: 'Site Content', page: 'Contact Us' };
    if (pathname === '/certificates') return { section: 'Certificates', page: 'Cert Records' };
    if (pathname === '/certificates/new') return { section: 'Certificates', page: 'Create Cert' };
    if (pathname.startsWith('/certificates/')) return { section: 'Certificates', page: 'Certificate Details' };
    if (pathname.startsWith('/users/')) return { section: 'User Activity', page: 'Profile' };
    if (pathname === '/ratings') return { section: 'Ratings', page: 'App Rating Review' };
    if (pathname === '/ratings/stream') return { section: 'Ratings', page: 'Ratings Stream' };
    if (pathname === '/feedback') return { section: 'Feedback', page: 'Bug Reports' };
    if (pathname === '/feedback/suggestions') return { section: 'Feedback', page: 'Suggestions' };
    if (pathname === '/feedback/questions') return { section: 'Feedback', page: 'Questions' };
    if (pathname === '/feedback/compliments') return { section: 'Feedback', page: 'Compliments' };
    if (pathname.startsWith('/reports/')) return { section: 'Incident Reports', page: 'Report Details' };
    for (const [base, label] of Object.entries(contentSections)) {
      if (pathname === `${base}/new`) return { section: label, page: 'New' };
      if (pathname.startsWith(`${base}/`)) return { section: label, page: 'Details' };
    }
    return { section: 'Dashboard', page: pageTitles[pathname] || 'Console' };
  }

  const crumb = getBreadcrumb(location.pathname);

  const today = new Date().toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'short',
    day: 'numeric'
  });

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand-block">
          <img src="/csalogo.png" alt="CSA logo" className="brand-mark" />
          <div>
            <h1>Admin Console</h1>
          </div>
        </div>

        <nav className="nav">
          {visibleNavItems.map((item) => {
            const isSectionActive = location.pathname === item.to || location.pathname.startsWith(`${item.to}/`);

            // Dynamic sub-entry: once a user profile is open, add a
            // "User Profile" link pointing at that user.
            let subNav = item.subNav;
            if (item.to === '/users' && /^\/users\/[^/]+$/.test(location.pathname)) {
              subNav = [...(item.subNav || []), { to: location.pathname, label: 'User Profile' }];
            }

            return (
              <div key={item.to}>
                <NavLink
                  to={item.to}
                  className={({ isActive }) =>
                    isActive || isSectionActive ? 'nav-link nav-link-active' : 'nav-link'
                  }
                >
                  <span>{item.label}</span>
                </NavLink>
                {subNav && isSectionActive ? (
                  <div className="nav-sublist">
                    {subNav.map((sub) => {
                      const current = location.pathname + location.search;
                      const querySubMatches = subNav.some(
                        (s) => s.to.includes('?') && s.to === current
                      );
                      const subActive = sub.to.includes('?')
                        ? sub.to === current
                        : location.pathname === sub.to && !querySubMatches;
                      return (
                        <NavLink
                          key={sub.to}
                          to={sub.to}
                          className={subActive ? 'nav-sublink nav-sublink-active' : 'nav-sublink'}
                        >
                          {sub.label}
                        </NavLink>
                      );
                    })}
                  </div>
                ) : null}
              </div>
            );
          })}
        </nav>

        <div className="mode-card sidebar-profile">
          <div className="profile-chip">
            <div className="profile-avatar">
              {admin.name?.slice(0, 2).toUpperCase()}
            </div>
            <div>
              <p className="profile-name">{admin.name}</p>
            </div>
          </div>
          <button type="button" className="secondary-button sidebar-button" onClick={onLogout}>
            Sign out
          </button>
        </div>
      </aside>

      <main className="content">
        <header className="topbar">
          <div>
            <div className="crumbs">{crumb.section} / {crumb.page}</div>
            <h2 className="topbar-title">{crumb.page}</h2>
          </div>

          <div className="topbar-actions">
            <div className="date-pill">{today}</div>
            <button
              type="button"
              className="icon-toggle"
              onClick={toggle}
              aria-label={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
              title={isDark ? 'Light mode' : 'Dark mode'}
            >
              {isDark ? '☀' : '☾'}
            </button>
          </div>
        </header>

        {children}
      </main>
    </div>
  );
}
