import { NextResponse } from "next/server";
import { sameOrigin } from "./portal";

export class ApiError extends Error {
  constructor(message: string, public status: number) { super(message); }
}

export async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const origin = process.env.SLATE_API_URL || "http://localhost:3000";
  let response: Response;
  try {
    response = await fetch(new URL(path, origin), { ...init, cache: "no-store", signal: AbortSignal.timeout(15_000),
      headers: { "Content-Type": "application/json", ...init?.headers } });
  } catch { throw new ApiError("Slate is temporarily unavailable. Please try again.", 503); }
  const payload = await response.json().catch(() => null);
  if (!response.ok) throw new ApiError(typeof payload?.error === "string" ? payload.error : "The request could not be completed.", response.status);
  if (!payload) throw new ApiError("Slate returned an unexpected response.", 502);
  return payload as T;
}

export function rejectCrossOrigin(request: Request) {
  if (!sameOrigin(request)) throw new ApiError("Request origin is not allowed.", 403);
}

export function errorResponse(error: unknown) {
  return NextResponse.json({ error: error instanceof ApiError ? error.message : "The request could not be completed." }, {
    status: error instanceof ApiError ? error.status : 500, headers: { "Cache-Control": "no-store" },
  });
}

export function portalPath(token: string) {
  if (!/^[A-Za-z0-9_-]{43}$/.test(token)) throw new ApiError("This private link is invalid or unavailable.", 404);
  return `/portal/${encodeURIComponent(token)}`;
}
