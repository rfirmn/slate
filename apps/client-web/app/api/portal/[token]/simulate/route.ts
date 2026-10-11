import { NextResponse } from "next/server";
import { api, ApiError, errorResponse, portalPath, rejectCrossOrigin } from "../../../../../lib/server";
import { developmentEnabled, paymentBelongsToPortal, type PortalData } from "../../../../../lib/portal";

export async function POST(request: Request, { params }: { params: Promise<{ token: string }> }) {
  try {
    if (!developmentEnabled(process.env)) throw new ApiError("Not found.", 404);
    rejectCrossOrigin(request);
    const { token } = await params;
    const body = await request.json().catch(() => { throw new ApiError("Invalid payment request.", 400); });
    const attemptId = body?.attemptId;
    if (typeof attemptId !== "string" || !/^[a-f\d-]{36}$/i.test(attemptId)) throw new ApiError("Invalid payment attempt.", 400);
    const data = await api<PortalData>(portalPath(token));
    if (!paymentBelongsToPortal(data, attemptId)) throw new ApiError("This payment is not available to this link.", 403);
    const result = await api<{ ok: boolean }>(`/dev/payments/${encodeURIComponent(attemptId)}/settle`, {
      method: "POST", headers: { "X-Dev-Secret": process.env.DEV_PAYMENT_SECRET! }, body: "{}",
    });
    return NextResponse.json(result);
  } catch (error) { return errorResponse(error); }
}
