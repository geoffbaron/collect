"use client";

import { useTransition } from "react";
import { completeInspection } from "@/lib/actions";
import { useRouter } from "next/navigation";

export default function CompleteButton({
  inspectionId,
  unitId,
}: {
  inspectionId: string;
  unitId: string;
}) {
  const [pending, start] = useTransition();
  const router = useRouter();

  function handleComplete() {
    start(async () => {
      await completeInspection(inspectionId, unitId);
      router.refresh();
    });
  }

  return (
    <button onClick={handleComplete} disabled={pending} className="btn-primary">
      {pending ? "Completing…" : "Mark Completed"}
    </button>
  );
}
