import Link from "next/link";
import { notFound } from "next/navigation";
import {
  getAccount,
  getAccountMembers,
  getAllWorkOrders,
  getProperties,
  getUser,
  type WorkOrderFilters,
} from "@/lib/data";
import {
  WORK_ORDER_CATEGORY_LABELS,
  WORK_ORDER_PRIORITY_LABELS,
  WORK_ORDER_STATUS_LABELS,
  type WorkOrderPriority,
  type WorkOrderStatus,
} from "@/lib/types";
import { formatDateOnly } from "@/lib/dates";

export const dynamic = "force-dynamic";

const STATUS_STYLES: Record<string, string> = {
  open: "bg-orange-100 text-orange-700",
  in_progress: "bg-blue-100 text-blue-700",
  completed: "bg-green-100 text-green-700",
  cancelled: "bg-slate-100 text-slate-600",
};

const STATUS_FILTERS = ["open_or_in_progress", "open", "in_progress", "completed", "cancelled"] as const;

export default async function AllWorkOrdersPage({
  searchParams,
}: {
  searchParams: { status?: string; priority?: string; propertyId?: string; assignee?: string };
}) {
  const [account, user, properties, members] = await Promise.all([
    getAccount(),
    getUser(),
    getProperties(),
    getAccountMembers(),
  ]);
  if (account?.product_mode !== "property_manager") notFound();

  const status = (STATUS_FILTERS as readonly string[]).includes(searchParams.status ?? "")
    ? (searchParams.status as WorkOrderFilters["status"])
    : undefined;
  const priority = (Object.keys(WORK_ORDER_PRIORITY_LABELS) as string[]).includes(searchParams.priority ?? "")
    ? (searchParams.priority as WorkOrderPriority)
    : undefined;
  const propertyId = properties.some((p) => p.id === searchParams.propertyId)
    ? searchParams.propertyId
    : undefined;
  const assignee = searchParams.assignee === "me" ? user?.id : searchParams.assignee;
  const assignedTo = members.some((m) => m.user_id === assignee) ? assignee : undefined;

  const workOrders = await getAllWorkOrders({ status, priority, propertyId, assignedTo });

  // Filter pills rebuild the query string with one param swapped.
  const qs = (overrides: Record<string, string | undefined>) => {
    const params = new URLSearchParams();
    const merged = {
      status: searchParams.status,
      priority: searchParams.priority,
      propertyId: searchParams.propertyId,
      assignee: searchParams.assignee,
      ...overrides,
    };
    for (const [k, v] of Object.entries(merged)) if (v) params.set(k, v);
    const s = params.toString();
    return s ? `/dashboard/work-orders?${s}` : "/dashboard/work-orders";
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Work Orders</h1>
        <p className="text-slate-500">Every ticket across your portfolio.</p>
      </div>

      <div className="flex flex-wrap items-center gap-2 text-sm">
        <FilterPill href={qs({ status: undefined })} active={!status} label="All statuses" />
        {STATUS_FILTERS.map((s) => (
          <FilterPill
            key={s}
            href={qs({ status: s })}
            active={status === s}
            label={s === "open_or_in_progress" ? "Open + In Progress" : WORK_ORDER_STATUS_LABELS[s as WorkOrderStatus]}
          />
        ))}
      </div>

      <div className="flex flex-wrap items-center gap-2 text-sm">
        <FilterPill href={qs({ assignee: undefined })} active={!searchParams.assignee} label="Anyone" />
        <FilterPill href={qs({ assignee: "me" })} active={searchParams.assignee === "me"} label="Assigned to me" />
        {members
          .filter((m) => m.user_id !== user?.id)
          .map((m) => (
            <FilterPill
              key={m.user_id}
              href={qs({ assignee: m.user_id })}
              active={searchParams.assignee === m.user_id}
              label={m.name || m.email || "Unknown"}
            />
          ))}
      </div>

      {properties.length > 1 && (
        <div className="flex flex-wrap items-center gap-2 text-sm">
          <FilterPill href={qs({ propertyId: undefined })} active={!propertyId} label="All properties" />
          {properties.map((p) => (
            <FilterPill key={p.id} href={qs({ propertyId: p.id })} active={propertyId === p.id} label={p.name} />
          ))}
        </div>
      )}

      <div className="card">
        <div className="border-b border-slate-200 px-5 py-3 font-semibold text-slate-900">
          {workOrders.length} ticket{workOrders.length !== 1 ? "s" : ""}
        </div>
        {workOrders.length === 0 ? (
          <div className="px-5 py-8 text-center text-slate-500">
            No work orders match these filters.
          </div>
        ) : (
          <ul className="divide-y divide-slate-100">
            {workOrders.map((wo) => (
              <li key={wo.id}>
                <Link
                  href={`/dashboard/portfolio/${wo.property_id}/work-orders/${wo.id}`}
                  className="flex items-center justify-between gap-3 px-5 py-4 hover:bg-slate-50"
                >
                  <div className="min-w-0">
                    <div className="truncate font-medium text-slate-900">{wo.title}</div>
                    <div className="text-sm text-slate-500">
                      {wo.property_name ?? "Unknown property"}
                      {wo.unit_number && ` · Unit ${wo.unit_number}`}
                      {" · "}
                      {WORK_ORDER_CATEGORY_LABELS[wo.category]}
                      {wo.due_date && ` · Due ${formatDateOnly(wo.due_date)}`}
                      {" · "}
                      {wo.assignee_name ?? "Unassigned"}
                    </div>
                  </div>
                  <div className="flex shrink-0 items-center gap-2">
                    <span className="rounded-full bg-orange-50 px-2 py-0.5 text-xs font-medium text-orange-700">
                      {WORK_ORDER_PRIORITY_LABELS[wo.priority]}
                    </span>
                    <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${STATUS_STYLES[wo.status]}`}>
                      {WORK_ORDER_STATUS_LABELS[wo.status]}
                    </span>
                  </div>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </div>

      <p className="text-sm text-slate-500">
        To create a work order, open a property and use its Work Orders page.
      </p>
    </div>
  );
}

function FilterPill({ href, active, label }: { href: string; active: boolean; label: string }) {
  return (
    <Link
      href={href}
      className={
        "rounded-full px-3 py-1.5 font-medium transition " +
        (active ? "bg-brand-100 text-brand-700" : "bg-slate-100 text-slate-600 hover:bg-slate-200")
      }
    >
      {label}
    </Link>
  );
}
