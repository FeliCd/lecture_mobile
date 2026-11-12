import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";
import { enforceSharedRateLimit, SharedDataset } from "./dataset";
import { groupSignup, parseSignupInput } from "./group-signup";

const dataset = defineString("SHARED_DATASET_ID", { default: "" });
const enabled = defineString("SHARED_GROUP_SIGNUP_ENABLED", { default: "false" });
const writeEnabled = defineString("SHARED_API_WRITES_ENABLED", { default: "false" });
const schoolDomains = defineString("SHARED_SCHOOL_DOMAINS", { default: "fpt.edu.vn,fe.edu.vn" });

export const sharedGroupSignup = onCall(
  { region: "asia-southeast1", maxInstances: 5 },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "UNAUTHENTICATED");
    if (enabled.value() !== "true" || !dataset.value())
      throw new HttpsError("failed-precondition", "SHARED_BACKEND_SETUP_REQUIRED");

    const data = parseSignupInput(request.data);
    const domains = new Set(schoolDomains.value().split(",").map((domain) => domain.trim().toLowerCase()));
    const db = getFirestore();
    const auth = request.auth;
    try {
      await enforceSharedRateLimit(db, auth.uid, "group-signup", 60);
      return await new SharedDataset(db, dataset.value()).run((rows) =>
        groupSignup(rows, auth.token, data, domains), writeEnabled.value() === "true", true);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof Error && error.message === "RATE_LIMITED")
        throw new HttpsError("resource-exhausted", "RATE_LIMITED", { code: "RATE_LIMITED" });
      console.error("Shared group signup failed", error instanceof Error ? error.name : "UnknownError");
      throw new HttpsError("internal", "SERVER_ERROR");
    }
  },
);
