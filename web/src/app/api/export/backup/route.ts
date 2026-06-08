import { createClient } from "@/lib/supabase/server";

/** Full account backup as JSON — re-importable via the Import panel. */
export async function GET() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return new Response("Unauthorized", { status: 401 });

  const tables = ["properties", "floors", "rooms", "collections", "assets"] as const;
  const out: Record<string, any[]> = {};

  for (const table of tables) {
    const { data, error } = await supabase.from(table).select("*").is("deleted_at", null);
    if (error) return new Response(error.message, { status: 500 });
    out[table] = data ?? [];
  }

  const backup = {
    version: 1,
    exported_at: new Date().toISOString(),
    ...out,
  };

  const date = new Date().toISOString().slice(0, 10);
  return new Response(JSON.stringify(backup, null, 2), {
    headers: {
      "Content-Type": "application/json",
      "Content-Disposition": `attachment; filename="collect-backup-${date}.json"`,
    },
  });
}
