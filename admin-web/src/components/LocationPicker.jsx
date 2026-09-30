import { useEffect, useMemo, useRef, useState } from 'react';
import L from 'leaflet';
import { MapContainer, Marker, TileLayer, useMap, useMapEvents } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import markerIcon2x from 'leaflet/dist/images/marker-icon-2x.png';
import markerIcon from 'leaflet/dist/images/marker-icon.png';
import markerShadow from 'leaflet/dist/images/marker-shadow.png';

// Vite serves the marker images as hashed URLs; Leaflet's built-in
// paths would 404 without this.
L.Icon.Default.mergeOptions({
  iconRetinaUrl: markerIcon2x,
  iconUrl: markerIcon,
  shadowUrl: markerShadow
});

const ACCRA = { lat: 5.6037, lng: -0.187 };
const NOMINATIM = 'https://nominatim.openstreetmap.org';

async function reverseGeocode(lat, lng) {
  const res = await fetch(
    `${NOMINATIM}/reverse?format=jsonv2&lat=${lat}&lon=${lng}&zoom=18&addressdetails=0`,
    { headers: { Accept: 'application/json' } }
  );
  if (!res.ok) return '';
  const data = await res.json();
  return data.display_name || '';
}

async function searchPlaces(query) {
  const res = await fetch(
    `${NOMINATIM}/search?format=jsonv2&q=${encodeURIComponent(query)}&limit=6`,
    { headers: { Accept: 'application/json' } }
  );
  if (!res.ok) return [];
  return res.json();
}

// Keeps the map centred on the current pin when it changes from outside
// (e.g. a search result was chosen).
function Recenter({ lat, lng }) {
  const map = useMap();
  useEffect(() => {
    if (lat != null && lng != null) map.setView([lat, lng], Math.max(map.getZoom(), 15));
  }, [lat, lng, map]);
  return null;
}

function ClickToPlace({ onPlace }) {
  useMapEvents({
    click(e) {
      onPlace(e.latlng.lat, e.latlng.lng);
    }
  });
  return null;
}

export default function LocationPicker({ value, onChange }) {
  const { location = '', latitude = null, longitude = null } = value || {};
  const hasPin = latitude != null && longitude != null;

  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [searching, setSearching] = useState(false);
  const debounceRef = useRef();

  const center = useMemo(
    () => (hasPin ? { lat: latitude, lng: longitude } : ACCRA),
    [hasPin, latitude, longitude]
  );

  useEffect(() => {
    if (query.trim().length < 3) {
      setResults([]);
      return;
    }
    clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(async () => {
      setSearching(true);
      try {
        setResults(await searchPlaces(query.trim()));
      } catch {
        setResults([]);
      } finally {
        setSearching(false);
      }
    }, 500);
    return () => clearTimeout(debounceRef.current);
  }, [query]);

  async function placePin(lat, lng, label) {
    const rounded = { lat: Number(lat.toFixed(6)), lng: Number(lng.toFixed(6)) };
    let text = label;
    if (!text) {
      try {
        text = await reverseGeocode(rounded.lat, rounded.lng);
      } catch {
        text = '';
      }
    }
    onChange({
      location: text || location,
      latitude: rounded.lat,
      longitude: rounded.lng
    });
  }

  function chooseResult(r) {
    setQuery('');
    setResults([]);
    placePin(parseFloat(r.lat), parseFloat(r.lon), r.display_name);
  }

  function clearPin() {
    onChange({ location, latitude: null, longitude: null });
  }

  return (
    <div className="location-picker">
      <div className="location-search">
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search a place or address…"
        />
        {results.length ? (
          <ul className="location-results">
            {results.map((r) => (
              <li key={r.place_id}>
                <button type="button" onClick={() => chooseResult(r)}>
                  {r.display_name}
                </button>
              </li>
            ))}
          </ul>
        ) : null}
      </div>

      <div className="location-map">
        <MapContainer
          center={[center.lat, center.lng]}
          zoom={hasPin ? 15 : 12}
          scrollWheelZoom
          style={{ height: '320px', width: '100%' }}
        >
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
            url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          <ClickToPlace onPlace={(lat, lng) => placePin(lat, lng)} />
          {hasPin ? (
            <>
              <Recenter lat={latitude} lng={longitude} />
              <Marker
                draggable
                position={[latitude, longitude]}
                eventHandlers={{
                  dragend: (e) => {
                    const { lat, lng } = e.target.getLatLng();
                    placePin(lat, lng);
                  }
                }}
              />
            </>
          ) : null}
        </MapContainer>
      </div>

      <p className="location-hint">
        {hasPin ? (
          <>
            Pinned at {latitude}, {longitude}.{' '}
            <button type="button" className="link-button" onClick={clearPin}>
              Clear pin
            </button>
          </>
        ) : (
          'Search above or click the map to drop a pin.'
        )}
      </p>

      <label>
        Address shown to citizens
        <input
          value={location}
          onChange={(e) => onChange({ location: e.target.value, latitude, longitude })}
          placeholder="e.g. CSA Head Office, Ridge, Accra"
        />
      </label>
    </div>
  );
}
