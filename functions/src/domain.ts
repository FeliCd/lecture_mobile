import { createHmac, timingSafeEqual } from "node:crypto";
export type QrPayload = {
  sessionId: string;
  slotId: number;
  sessionVersion: number;
  expiresAt: number;
  secretRequired?: boolean;
};
export function signQr(payload: QrPayload, secret: string): string {
  const body = Buffer.from(JSON.stringify(payload)).toString("base64url");
  return `${body}.${createHmac("sha256", secret).update(body).digest("base64url")}`;
}
export function verifyQr(
  token: string,
  secret: string,
  now: number,
): QrPayload {
  try {
    const [body, signature, extra] = token.split(".");
    if (!body || !signature || extra) throw Error("QR_INVALID");
    const expected = createHmac("sha256", secret).update(body).digest();
    const actual = Buffer.from(signature, "base64url");
    if (actual.length !== expected.length || !timingSafeEqual(actual, expected))
      throw Error("QR_INVALID");
    const p = JSON.parse(
      Buffer.from(body, "base64url").toString(),
    ) as QrPayload;
    if (
      typeof p.sessionId !== "string" ||
      !Number.isInteger(p.slotId) ||
      !Number.isInteger(p.sessionVersion) ||
      !Number.isFinite(p.expiresAt)
    )
      throw Error("QR_INVALID");
    if (now >= p.expiresAt) throw Error("QR_EXPIRED");
    if (p.slotId !== Math.floor(now / 120000)) throw Error("QR_EXPIRED");
    return p;
  } catch (e) {
    throw Error(
      e instanceof Error && e.message === "QR_EXPIRED"
        ? "QR_EXPIRED"
        : "QR_INVALID",
    );
  }
}
export function attendanceRate(statuses: string[]): number | null {
  const eligible = statuses.filter((s) => s !== "excused");
  return eligible.length
    ? (eligible.filter((s) => s === "present" || s === "late").length /
        eligible.length) *
        100
    : null;
}
