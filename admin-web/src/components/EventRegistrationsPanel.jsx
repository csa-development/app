import RegistrationsPanel from './RegistrationsPanel';
import { checkInRegistration, getEventRegistrations } from '../services/api';

// Registrations + check-in for an event. `item` is the event.
export default function EventRegistrationsPanel({ item: event }) {
  return (
    <RegistrationsPanel
      id={event.id}
      fetchRegistrations={getEventRegistrations}
      checkIn={checkInRegistration}
    />
  );
}
