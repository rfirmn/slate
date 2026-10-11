import { NextResponse } from "next/server";
import { api, ApiError, errorResponse, portalPath } from "../../../../../../../lib/server";
import { safeURL } from "../../../../../../../lib/portal";

export async function GET(_request: Request, { params }: { params: Promise<{ token: string; id: string }> }) {
  try {
    const { token, id } = await params;
    const data = await api<{ url: string }>(`${portalPath(token)}/media/${encodeURIComponent(id)}/download`);
    if (!safeURL(data.url)) throw new ApiError("The download URL is unavailable.", 502);
    return NextResponse.json(data);
  } catch (error) { return errorResponse(error); }
}
