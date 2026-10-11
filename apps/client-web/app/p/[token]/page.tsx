import Portal from "./portal";

export default async function PortalPage({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  return <Portal token={token} />;
}
