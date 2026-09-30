export default function ListToolbar({
  searchValue,
  onSearchChange,
  searchPlaceholder = 'Search',
  filterValue,
  onFilterChange,
  filterOptions = [],
  resultLabel
}) {
  return (
    <div className="list-toolbar">
      <input
        className="toolbar-search"
        value={searchValue}
        onChange={(event) => onSearchChange(event.target.value)}
        placeholder={searchPlaceholder}
      />

      {filterOptions.length ? (
        <select
          className="filter-select"
          value={filterValue}
          onChange={(event) => onFilterChange(event.target.value)}
        >
          {filterOptions.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      ) : null}

      <span className="toolbar-result">{resultLabel}</span>
    </div>
  );
}
