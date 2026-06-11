import type { Building, CommonArea, Unit } from "@/lib/types";

/// Dropdown for scoping a work order / capital asset / maintenance schedule
/// to the whole property, a building, a unit, or a common area.
export default function LocationSelect({
  value,
  onChange,
  buildings,
  units,
  commonAreas,
}: {
  value: string;
  onChange: (value: string) => void;
  buildings: Building[];
  units: Unit[];
  commonAreas: CommonArea[];
}) {
  const buildingName = (buildingId: string | null) =>
    buildings.find((b) => b.id === buildingId)?.name;

  return (
    <div>
      <label className="label" htmlFor="location-select">Location</label>
      <select id="location-select" className="input" value={value} onChange={(e) => onChange(e.target.value)}>
        <option value="property">Whole Property</option>
        {buildings.length > 0 && (
          <optgroup label="Buildings">
            {buildings.map((b) => (
              <option key={b.id} value={`building:${b.id}`}>{b.name}</option>
            ))}
          </optgroup>
        )}
        {units.length > 0 && (
          <optgroup label="Units">
            {units.map((u) => {
              const building = buildingName(u.building_id);
              return (
                <option key={u.id} value={`unit:${u.id}`}>
                  Unit {u.unit_number}{building ? ` (${building})` : ""}
                </option>
              );
            })}
          </optgroup>
        )}
        {commonAreas.length > 0 && (
          <optgroup label="Common Areas">
            {commonAreas.map((c) => {
              const building = buildingName(c.building_id);
              return (
                <option key={c.id} value={`commonArea:${c.id}`}>
                  {c.name}{building ? ` (${building})` : ""}
                </option>
              );
            })}
          </optgroup>
        )}
      </select>
    </div>
  );
}

/// Parses a LocationSelect value into the buildingId/unitId/commonAreaId
/// fields expected by the create* server actions.
export function parseLocationValue(
  value: string,
  units: Unit[],
  commonAreas: CommonArea[]
): { buildingId?: string | null; unitId?: string | null; commonAreaId?: string | null } {
  if (value.startsWith("building:")) {
    return { buildingId: value.slice("building:".length) };
  }
  if (value.startsWith("unit:")) {
    const unitId = value.slice("unit:".length);
    const unit = units.find((u) => u.id === unitId);
    return { unitId, buildingId: unit?.building_id ?? null };
  }
  if (value.startsWith("commonArea:")) {
    const commonAreaId = value.slice("commonArea:".length);
    const commonArea = commonAreas.find((c) => c.id === commonAreaId);
    return { commonAreaId, buildingId: commonArea?.building_id ?? null };
  }
  return {};
}
