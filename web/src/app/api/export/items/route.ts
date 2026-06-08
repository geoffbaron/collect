import { createClient } from "@/lib/supabase/server";

function csvCell(value: unknown): string {
  const s = value == null ? "" : String(value);
  return `"${s.replace(/"/g, '""')}"`;
}

export async function GET() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return new Response("Unauthorized", { status: 401 });

  const { data, error } = await supabase
    .from("assets")
    .select(
      "name, category, asset_description, condition, quantity, estimated_value, listing_status, asking_price, collection:collections(room:rooms(name, floor:floors(name, property:properties(name))))"
    )
    .is("deleted_at", null)
    .order("updated_at", { ascending: false });

  if (error) return new Response(error.message, { status: 500 });

  const header = [
    "Property",
    "Floor",
    "Room",
    "Name",
    "Category",
    "Description",
    "Condition",
    "Quantity",
    "Estimated Value",
    "Listing Status",
    "Asking Price",
  ];

  const rows = (data ?? []).map((a: any) => {
    const room = a.collection?.room;
    const floor = room?.floor;
    const property = floor?.property;
    return [
      property?.name ?? "",
      floor?.name ?? "",
      room?.name ?? "",
      a.name,
      a.category,
      a.asset_description,
      a.condition ?? "",
      a.quantity,
      a.estimated_value ?? "",
      a.listing_status,
      a.asking_price ?? "",
    ]
      .map(csvCell)
      .join(",");
  });

  const csv = [header.map(csvCell).join(","), ...rows].join("\n");
  const date = new Date().toISOString().slice(0, 10);

  return new Response(csv, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="collect-items-${date}.csv"`,
    },
  });
}
