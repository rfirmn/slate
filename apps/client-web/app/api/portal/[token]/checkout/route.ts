import { NextResponse } from "next/server";
import { api, ApiError, errorResponse, portalPath, rejectCrossOrigin } from "../../../../../lib/server";
import { safeURL } from "../../../../../lib/portal";

export async function POST(request: Request, { params }: { params: Promise<{ token: string }> }) {
  try {
    rejectCrossOrigin(request);
    const { token } = await params;
    const key = request.headers.get("Idempotency-Key");
    if (!key || !/^[a-f\d-]{36}$/i.test(key)) throw new ApiError("A valid checkout request key is required.", 400);
    const data = await api<{ redirectURL: string; attemptId: string }>(`${portalPath(token)}/checkout`, {
      method: "POST", headers: { "Idempotency-Key": key }, body: "{}",
    });
    if (!safeURL(data.redirectURL)) throw new ApiError("The checkout URL is unavailable.", 502);
    return NextResponse.json(data);
  } catch (error) { return errorResponse(error); }
}
