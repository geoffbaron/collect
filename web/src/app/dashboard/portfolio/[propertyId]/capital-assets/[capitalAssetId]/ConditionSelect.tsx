"use client";

import { useTransition } from "react";
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
  const router = useRouter();

  function handleChange(next: CapitalAssetCondition) {
    start(async () => {
      await updateCapitalAssetCondition(capitalAssetId, propertyId, next);
      router.refresh();
    });
  }

  return (
    <div>
      <label className="label">Condition</label>
      <select
        className="input max-w-xs"
        value={condition}
        disabled={pending}
        onChange={(e) => handleChange(e.target.value as CapitalAssetCondition)}
      >
        {CONDITIONS.map(([value, label]) => (
          <option key={value} value={value}>{label}</option>
        ))}
      </select>
    </div>
  );
}
