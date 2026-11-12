import { randomUUID } from "node:crypto";
import type { DecodedIdToken } from "firebase-admin/auth";
import { HttpsError } from "firebase-functions/v2/https";
import { z } from "zod";
import { rowId, SharedRows } from "./dataset";

const table = {
  classes: "Classes",
  lecturers: "Lecturers",
  students: "Students",
  enrollments: "Enrollments",
  signup: "PortalGroupSignups",
  plans: "PortalGroupPlans",
  audit: "PortalAudit",
};
const group = z.object({ id: z.string().min(1), name: z.string(), memberIds: z.array(z.string()) });
const input = z.discriminatedUnion("action", [
  z.object({ action: z.literal("status"), classId: z.string().min(1).max(120) }).strict(),
  z.object({ action: z.literal("plan"), classId: z.string().min(1).max(120) }).strict(),
  z.object({ action: z.literal("open"), classId: z.string().min(1).max(120),
    version: z.number().int().nonnegative(), groupCount: z.number().int().min(1).max(50),
    requestKey: z.string().regex(/^[A-Za-z0-9-]{16,80}$/) }).strict(),
  z.object({ action: z.literal("choose"), classId: z.string().min(1).max(120),
    roundId: z.string().uuid(), groupId: z.string().min(1).max(120) }).strict(),
  z.object({ action: z.literal("close"), classId: z.string().min(1).max(120),
    roundId: z.string().uuid() }).strict(),
]);

function deny(code = "PERMISSION_DENIED"): never {
  throw new HttpsError("permission-denied", code, { code });
}
function conflict(code: string): never {
  throw new HttpsError("failed-precondition", code, { code });
}
export function parseSignupInput(value: unknown) {
  const parsed = input.safeParse(value);
  if (!parsed.success) throw new HttpsError("invalid-argument", "INVALID_INPUT");
  return parsed.data;
}

export async function groupSignup(
  rows: SharedRows,
  auth: Pick<DecodedIdToken, "email" | "email_verified" | "firebase">,
  data: z.infer<typeof input>,
  domains: ReadonlySet<string>,
) {
  const email = auth.email?.trim().toLowerCase();
  if (!auth.email_verified || !email) deny();
  const cls = await rows.get(table.classes, "classId", data.classId);
  if (!cls) deny();

  const [lecturers, enrollments] = await Promise.all([
    rows.where(table.lecturers, "lecturerId", "identityEmail", email),
    rows.where(table.enrollments, "enrollmentId", "row.classId", data.classId),
  ]);
  if (lecturers.length > 1) deny("DUPLICATE_PROFILE");
  const teacher = lecturers.length === 1 && lecturers[0].lecturerId === cls.lecturerId &&
    domains.has(email.split("@")[1]) && auth.firebase.sign_in_provider === "google.com";
  const roster = new Set(enrollments.map((entry) => entry.studentId));
  let studentId = "";
  if (!teacher) {
    const students = await rows.where(table.students, "studentId", "identityEmail", email);
    if (students.length !== 1 || !roster.has(students[0].studentId)) deny("NOT_ENROLLED");
    studentId = students[0].studentId;
  }
  if ((data.action === "open" || data.action === "close") && !teacher) deny();
  if (data.action === "choose" && teacher) deny();

  const [existing, storedPlan] = await Promise.all([
    rows.get(table.signup, "classId", data.classId),
    rows.get(table.plans, "classId", data.classId),
  ]);
  let round = existing;
  let groups = storedPlan ? group.array().parse(JSON.parse(storedPlan.groups)) : [];
  let version = Number(storedPlan?.version ?? 0);
  if (!Number.isSafeInteger(version) || version < 0) throw new Error("INVALID_GROUP_PLAN");
  const now = new Date().toISOString();
  const actor = teacher ? "lecturer-" + cls.lecturerId : "student-" + studentId;
  if (data.action === "plan") {
    const visible = teacher ? groups : groups.filter((item) => item.memberIds.includes(studentId));
    const ids = teacher ? [...roster] : [...new Set(visible.flatMap((item) => item.memberIds))].filter((id) => roster.has(id));
    if (ids.length > 400) conflict("CLASS_TOO_LARGE");
    const students = await rows.getAll(table.students, "studentId", ids);
    return {
      classId: data.classId, viewerId: actor, version, groups: visible,
      students: students.map(({ studentId, studentCode, fullName }) => ({
        studentId, studentCode: studentCode || "", fullName: fullName || "",
      })),
    };
  }

  const savePlan = (requestKey: string) => {
    version++;
    rows.set(table.plans, "classId", {
      classId: data.classId, groups: JSON.stringify(groups), version, updatedAt: now,
      updatedBy: actor, requestKey,
    });
  };
  const audit = (action: string, roundId: string, detail: unknown) => {
    rows.set(table.audit, "id", {
      id: randomUUID(), classId: data.classId, entityId: roundId, actor, action,
      at: now, detail: JSON.stringify(detail),
    });
  };

  if (data.action === "open" && data.requestKey !== round?.requestKey) {
    if (round?.state === "OPEN") conflict("GROUP_SIGNUP_OPEN");
    const legacy = await rows.get("PortalGroupSignupSheets", "classId", data.classId);
    if (["PREPARING", "OPEN", "CONFLICT"].includes(legacy?.state ?? ""))
      conflict("LEGACY_GROUP_SIGNUP_OPEN");
    if (data.version !== version) conflict("VERSION_CONFLICT");
    if (!roster.size) conflict("EMPTY_ROSTER");
    if (roster.size > 400) conflict("CLASS_TOO_LARGE");
    const roundId = randomUUID();
    if (!groups.length) {
      groups = Array.from({ length: data.groupCount }, (_, index) => ({
        id: randomUUID(), name: "Nhóm " + (index + 1), memberIds: [],
      }));
      savePlan("signup-open-" + roundId);
    }
    round = { classId: data.classId, roundId, state: "OPEN", requestKey: data.requestKey,
      createdAt: now, updatedAt: now, closedAt: "" };
    rows.set(table.signup, "classId", round);
    audit("OPEN_GROUP_SIGNUP", roundId, { groupCount: groups.length });
  }

  if (data.action === "choose") {
    if (round?.state !== "OPEN" || round.roundId !== data.roundId) conflict("GROUP_SIGNUP_NOT_OPEN");
    if (!groups.some((item) => item.id === data.groupId)) conflict("INVALID_GROUPS");
    const memberships = groups.filter((item) => item.memberIds.includes(studentId));
    if (memberships.length !== 1 || memberships[0].id !== data.groupId) {
      groups = groups.map((item) => ({
        ...item,
        memberIds: [
          ...item.memberIds.filter((member) => member !== studentId),
          ...(item.id === data.groupId ? [studentId] : []),
        ],
      }));
      savePlan("signup-choice-" + randomUUID());
      rows.set(table.signup, "classId", { ...round, updatedAt: now });
      audit("CHOOSE_GROUP", round.roundId, { groupId: data.groupId });
    }
  }

  if (data.action === "close") {
    if (!round || round.roundId !== data.roundId) conflict("GROUP_SIGNUP_NOT_FOUND");
    if (round.state === "OPEN") {
      round = { ...round, state: "CLOSED", updatedAt: now, closedAt: now };
      rows.set(table.signup, "classId", round);
      audit("CLOSE_GROUP_SIGNUP", round.roundId, {});
    }
  }

  if (!round || (!teacher && round.state !== "OPEN")) return { state: "NONE", currentPlanVersion: version };
  return {
    state: round.state, roundId: round.roundId, currentPlanVersion: version,
    selectedGroupId: studentId ? groups.find((item) => item.memberIds.includes(studentId))?.id ?? null : null,
    groups: groups.map(({ id, name }) => ({ id, name })),
    groupCount: groups.length,
    studentCount: roster.size,
    assignedCount: new Set(groups.flatMap(({ memberIds }) => memberIds).filter((id) => roster.has(id))).size,
  };
}
