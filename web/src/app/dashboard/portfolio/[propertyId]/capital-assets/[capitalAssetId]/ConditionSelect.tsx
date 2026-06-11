"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { updateCapitalAssetCondition } from "@/lib/actions";
import { CAPITAL_ASSET_CONDITION_LABELS, type CapitalAssetCondition } from "@/lib/types";

const CONDITIONS = Object.entries(CAPITAL_ASSET_CONDITION_LABELS) as [CapitalAssetCondition, string][];

export default function ConditionSelect({
  capitalAssetId,
  propertyId,
  condition,
}: {
  capitalAssetId: string;
  propertyId: string;
  condition: CapitalAssetCondition;
}) {
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  function handleChange(next: CapitalAssetCondition) {
    setError(null);
    start(async () => {
      const result = await updateCapitalAssetCondition(capitalAssetId, propertyId, next);
      if (!result.ok) { setError(result.error ?? "Failed to update condition."); return; }
      router.refresh();
    });
  }

  return (
    <div>
      <label className="label" htmlFor="ca-condition">Condition</label>
      <select
        id="ca-condition"
        className="input max-w-xs"
        value={condition}
        disabled={pending}
        onChange={(e) => handleChange(e.target.value as CapitalAssetCondition)}
      >
        {CONDITIONS.map(([value, label]) => (
          <option key={value} value={value}>{label}</option>
        ))}
      </select>
      {error && <p className="mt-1 text-sm text-red-600">{error}</p>}
    </div>
  );
}
