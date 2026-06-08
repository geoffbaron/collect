import { getAssetsWithLocation } from "@/lib/data";
import { ItemsTable } from "./ItemsTable";

export const dynamic = "force-dynamic";

export default async function ItemsPage() {
  const assets = await getAssetsWithLocation();
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Items</h1>
        <p className="text-slate-500">Search, edit, and organize everything in your inventory.</p>
      </div>
      <ItemsTable initialAssets={assets} />
    </div>
  );
}
