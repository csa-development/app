export const SUPERADMIN = 'SUPERADMIN';
export const CERT = 'CERT';
export const IT = 'IT';
export const LECO = 'LECO';
export const COMMS = 'COMMS';

// Where each role lands immediately after login.
export const ROLE_HOME = {
  [SUPERADMIN]: '/dashboard',
  [CERT]: '/dashboard/cert',
  [IT]: '/dashboard/it',
  [LECO]: '/certificates',
  [COMMS]: '/alerts'
};

export function roleHomePath(admin) {
  return ROLE_HOME[admin?.primary_role] || null;
}

export function hasRole(admin, roles) {
  if (!admin) return false;
  if ((admin.roles || []).includes(SUPERADMIN)) return true;
  return (admin.roles || []).some((role) => roles.includes(role));
}
