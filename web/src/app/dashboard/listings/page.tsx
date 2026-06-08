import { getAssetsWithLocation } from "@/lib/data";
import { ListingsBoard } from "./ListingsBoard";

export const dynamic = "force-dynamic";

export default async function ListingsPage() {
  const assets = await getAssetsWithLocation();
  const listings = assets.filter((a) => a.listing_status !== "not_listed");
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Listings</h1>
        <p className="text-slate-500">Track items through ready → listed → pending → sold.</p>
      </div>
      <ListingsBoard initialListings={listings} />
    </div>
  );
}
