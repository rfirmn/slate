import { NextResponse } from "next/server";
import { api, errorResponse, portalPath } from "../../../../lib/server";
import { developmentEnabled, type PortalData } from "../../../../lib/portal";

export async function GET(_request: Request, { params }: { params: Promise<{ token: string }> }) {
  try {
    const { token } = await params;
    const data = await api<PortalData>(portalPath(token));
    return NextResponse.json({ ...data, developmentPayments: data.developmentPayments && developmentEnabled(process.env) });
  } catch (error) { return errorResponse(error); }
}
