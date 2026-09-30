import { Navigate } from 'react-router-dom';
import { hasRole, roleHomePath } from '../roleAccess';

export default function RoleRoute({ admin, roles, children }) {
  if (hasRole(admin, roles)) {
    return children;
  }

  return <Navigate to={roleHomePath(admin) || '/dashboard'} replace />;
}
