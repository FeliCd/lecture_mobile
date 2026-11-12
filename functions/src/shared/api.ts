import { OAuth2Client } from "google-auth-library";
import { groupSignup, parseSignupInput } from "./group-signup";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { defineSecret, defineString } from "firebase-functions/params";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { enforceSharedRateLimit, SharedDataset, SharedRows } from "./dataset";
import { dispatch, lab2Health_, pushRecipients, reconcileExpiredSessions, reconcileTaskMail } from "./domain/logic";

const datasetId = defineString("SHARED_DATASET_ID", { default: "" });
const writerEnabled = defineString("SHARED_API_WRITES_ENABLED", { default: "false" });
const desktopAudience = defineString("SHARED_DESKTOP_GOOGLE_CLIENT_ID", { default: "" });
const signupEnabled = defineString("SHARED_GROUP_SIGNUP_ENABLED", { default: "false" });
const schoolDomains = defineString("SHARED_SCHOOL_DOMAINS", { default: "fpt.edu.vn,fe.edu.vn" });
const taskMailEnabled = defineString("SHARED_TASK_MAIL_ENABLED", { default: "false" });
const openAlexKey = defineSecret("OPENALEX_API_KEY");
const google = new OAuth2Client();
const region = "asia-southeast1";
const db = () => getFirestore();
const dataset = () => new SharedDataset(db(), datasetId.value());
const writesAllowed = () => writerEnabled.value() === "true";
type Identity = { email: string; firebaseUid: string; signInProvider: string };
type Push = {
  actor: { uid: string; role: string; entity: object };
  event: { classId: string; groupId: string };
  messageId: string;
};

async function sendPush(push: Push): Promise<void> {
  if (process.env.FUNCTIONS_EMULATOR === "true") return;
  const devices = await dataset().run((rows) =>
    pushRecipients(rows, push.actor, push.event), false);
  if (!devices.length) return;
  const link = "https://fap-sinhvien.web.app/?chatClass=" + encodeURIComponent(push.event.classId);
  await getMessaging().sendEach(devices.slice(0, 500).map((device: Record<string, string>) => ({
    token: device.token,
    notification: { title: "Tin nhắn nhóm mới", body: "Mở FAP Attendance để xem hội thoại." },
    data: { screen: "group-chat", ...push.event, messageId: push.messageId, recipientUid: device.firebaseUid },
    android: { ttl: 3600000, notification: { tag: push.messageId } },
    webpush: { headers: { TTL: "3600" }, fcmOptions: { link }, notification: { tag: push.messageId } },
  })));
}

function bodyObject(value: unknown): Record<string, any> {
  if (typeof value === "string") {
    try { value = JSON.parse(value); } catch { throw Error("INVALID_INPUT"); }
  }
  if (!value || typeof value !== "object" || Array.isArray(value)) throw Error("INVALID_INPUT");
  return value as Record<string, any>;
}

function wrapBook(rows: SharedRows, identity: Identity, events: Push[]) {
  return Object.assign(rows, {
    identity,
    pushAfterCommit(actor: Push["actor"], result: any) {
      if (!result?._groupPush) return result;
      const { _groupPush, ...publicResult } = result;
      events.push({ actor, event: _groupPush, messageId: result.id });
      return publicResult;
    },
  });
}

export const sharedApi = onRequest(
  { region, cors: true, maxInstances: 10, timeoutSeconds: 60, secrets: [openAlexKey] },
  async (req, res) => {
    res.set("Cache-Control", "no-store");
    if (req.method !== "POST") {
      res.status(405).json({ ok: false, error: "METHOD_NOT_ALLOWED" });
      return;
    }
    try {
      if ((req.rawBody?.length ?? 0) > 2000000) throw Error("INVALID_INPUT");
      const request = bodyObject(req.body);
      if (typeof request.action !== "string" || !/^[a-zA-Z][a-zA-Z0-9]{2,44}$/.test(request.action))
        throw Error("INVALID_INPUT");
      const large = request.action === "portalCall" ||
        (request.action === "lab2Call" && ["groupCall", "portalCall"].includes(request.name));
      if (!large && (req.rawBody?.length ?? 0) > 200000) throw Error("INVALID_INPUT");
      if (!datasetId.value()) throw Error("SHARED_BACKEND_SETUP_REQUIRED");

      if (request.action === "lab2Health") {
        const active = await dataset().run(async (rows) => rows.firebaseWriter, false);
        res.json({ ok: true, data: { ...lab2Health_(), writesEnabled: writesAllowed() && active } });
        return;
      }
      const authorization = /^(Bearer|Google) (\S+)$/.exec(req.get("Authorization") ?? "");
      const token = authorization?.[2];
      if (!token || token.length > 10000) throw Error("UNAUTHENTICATED");
      let identity: Identity;
      if (authorization[1] === "Google") {
        const audience = desktopAudience.value();
        if (!audience || request.firebaseAuth === true ||
            /^(student|lab2)/.test(request.action)) throw Error("UNAUTHENTICATED");
        const payload = await google.verifyIdToken({ idToken: token, audience })
          .then((ticket) => ticket.getPayload()).catch(() => undefined);
        if (!payload?.email || payload.email_verified !== true) throw Error("UNAUTHENTICATED");
        identity = { email: payload.email.trim().toLowerCase(), firebaseUid: "desktop-" + payload.sub, signInProvider: "google.com" };
      } else {
        const claims = await getAuth().verifyIdToken(token, true).catch(() => {
          throw Error("UNAUTHENTICATED");
        });
        if (claims.email_verified !== true || !claims.email) throw Error("EMAIL_NOT_VERIFIED");
        identity = { email: claims.email.trim().toLowerCase(), firebaseUid: claims.uid, signInProvider: claims.firebase.sign_in_provider };
      }
      const action = String(request.name || request.method || request.action);
      if (!/^[a-zA-Z][a-zA-Z0-9]{1,59}$/.test(action)) throw Error("INVALID_INPUT");
      const limit = ["discoverArticles", "getSubjectUpdates", "studentCheckIn"].includes(action) ? 12 : 60;
      await enforceSharedRateLimit(db(), identity.firebaseUid, action, limit);
      const outcome = await dataset().run(async (rows) => {
        const events: Push[] = [];
        let data;
        if (request.action === "groupSignup") {
          if (signupEnabled.value() !== "true") throw Error("SHARED_BACKEND_SETUP_REQUIRED");
          const domains = new Set(schoolDomains.value().split(",").map(value => value.trim().toLowerCase()));
          data = await groupSignup(rows, {
            email: identity.email, email_verified: true,
            firebase: { identities: {}, sign_in_provider: identity.signInProvider },
          }, parseSignupInput(request.input), domains);
        } else {
          data = await dispatch(wrapBook(rows, identity, events), request);
        }
        return { data, events };
      }, writesAllowed(), true);
      for (const event of outcome.events) {
        await sendPush(event).catch(() => console.warn("Group message saved; push failed"));
      }
      res.json({ ok: true, data: outcome.data });
    } catch (error) {
      const code = error instanceof Error ? error.message : "";
      const publicError = /^[A-Z][A-Z0-9_]{2,80}$/.test(code) ||
        (code.length < 240 && /^[\p{L}\p{M}\p{N}\s.,!?/()'-]+$/u.test(code) && /[^\x00-\x7f]/.test(code));
      if (!publicError) console.error("Shared API failure", error instanceof Error ? error.name : "UnknownError");
      res.json({ ok: false, error: publicError ? code : "SERVER_ERROR" });
    }
  },
);

export const finalizeSharedAttendance = onSchedule(
  { region, schedule: "every 1 minutes", maxInstances: 1, timeZone: "Asia/Ho_Chi_Minh" },
  async () => {
    if (!writesAllowed() || !datasetId.value()) return;
    await dataset().run(reconcileExpiredSessions, true, true);
  },
);

export const processSharedTaskMail = onSchedule(
  { region, schedule: "every 5 minutes", maxInstances: 1, timeZone: "Asia/Ho_Chi_Minh" },
  async () => {
    if (!writesAllowed() || taskMailEnabled.value() !== "true" || !datasetId.value()) return;
    await dataset().run(reconcileTaskMail, true, true);
  },
);
