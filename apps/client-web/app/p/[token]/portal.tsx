"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { deliveryAvailable, money, newIdempotencyKey, safeURL, type Media, type PortalData } from "../../../lib/portal";

type Failure = { message: string; status: number };

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  let response: Response;
  try { response = await fetch(path, { ...init, cache: "no-store", signal: AbortSignal.timeout(20_000) }); }
  catch { throw { message: "Connection interrupted. Please try again.", status: 503 } satisfies Failure; }
  const data = await response.json().catch(() => null);
  if (!response.ok || !data) throw { message: data?.error || "The request could not be completed.", status: response.status } satisfies Failure;
  return data as T;
}

function date(value?: string) {
  if (!value) return "—";
  return new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", year: "numeric" }).format(new Date(value));
}
function fileSize(bytes: number) {
  return bytes >= 1024 * 1024 ? `${(bytes / 1024 / 1024).toFixed(1)} MB` : `${Math.ceil(bytes / 1024)} KB`;
}

export default function Portal({ token }: { token: string }) {
  const base = `/api/portal/${encodeURIComponent(token)}`;
  const [data, setData] = useState<PortalData | null>(null);
  const [failure, setFailure] = useState<Failure | null>(null);
  const [notice, setNotice] = useState("");
  const [refreshing, setRefreshing] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const checkoutKey = useRef<string | null>(null);
  const refreshVersion = useRef(0);

  const refresh = useCallback(async () => {
    const version = ++refreshVersion.current;
    setRefreshing(true);
    try {
      const result = await request<PortalData>(base);
      if (version !== refreshVersion.current) return;
      setData(result); setFailure(null);
    }
    catch (error) {
      if (version !== refreshVersion.current) return;
      const failed = error as Failure;
      setFailure(failed);
      if ([401, 403, 404, 410].includes(failed.status)) setData(null);
    } finally { if (version === refreshVersion.current) setRefreshing(false); }
  }, [base]);

  useEffect(() => { void refresh(); }, [refresh]);

  async function checkout() {
    setBusy("checkout"); setNotice("");
    try {
      checkoutKey.current ||= newIdempotencyKey();
      const result = await request<{ redirectURL: string }>(`${base}/checkout`, {
        method: "POST", headers: { "Idempotency-Key": checkoutKey.current },
      });
      const url = safeURL(result.redirectURL);
      if (!url) throw { message: "The checkout URL is unavailable.", status: 502 };
      window.location.assign(url);
    } catch (error) { setNotice((error as Failure).message); setBusy(null); }
  }

  async function download(id: string) {
    setBusy(id); setNotice("");
    try {
      const result = await request<{ url: string }>(`${base}/media/${encodeURIComponent(id)}/download`);
      const url = safeURL(result.url);
      if (!url) throw { message: "The download URL is unavailable.", status: 502 };
      window.location.assign(url);
    } catch (error) { setNotice((error as Failure).message); await refresh(); }
    finally { setBusy(null); }
  }

  async function simulate(attemptId: string) {
    setBusy("simulate"); setNotice("");
    try {
      await request(`${base}/simulate`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ attemptId }) });
      await refresh();
      setNotice("Local provider event processed. The payment status above comes from Slate.");
    } catch (error) { setNotice((error as Failure).message); }
    finally { setBusy(null); }
  }

  const invoice = data?.project.invoice;
  const paid = invoice?.status === "PAID";
  const revoked = data?.deliveryStatus === "REVOKED";
  const unlocked = data ? deliveryAvailable(data) : false;
  const pendingSimulation = invoice?.payments.find((payment) => payment.provider === "development" && ["CREATED", "PENDING"].includes(payment.status));

  return <div className="portal-shell">
    <header className="site-header"><a className="brand" href="/" aria-label="Slate home"><span className="brand-mark">s</span>slate<span className="brand-dot">.</span></a>
      <span className="private-link"><Lock /> Private client space</span>
    </header>
    {!data ? <main className="entry-state" aria-busy={refreshing}>
      <span className="eyebrow">YOUR PROJECT SPACE</span>
      <h1>{failure ? ([401, 403, 404, 410].includes(failure.status) ? "This link is unavailable." : "A little interruption.") : "Preparing your project."}</h1>
      <p>{failure ? ([401, 403, 404, 410].includes(failure.status) ? "Your private link may have expired or been revoked. Ask your creator for a new link." : failure.message) : "Gathering your invoice and previews…"}</p>
      {failure && <button className="button secondary" onClick={() => void refresh()} disabled={refreshing}>{refreshing ? "Checking…" : "Try again"}</button>}
      {!failure && <div className="skeletons"><div /><div /><div /></div>}
    </main> : <main className="portal-main">
      <section className="hero"><div><div className="eyebrow">A PROJECT FOR {data.project.client.name}</div>
        <h1>{data.project.title}</h1><p>{data.project.description || "Your work, thoughtfully brought together. Review the previews below, then receive the finished files when your project is ready."}</p>
      </div><div className="hero-aside"><span className={`status ${unlocked ? "positive" : ""}`}><span />{revoked ? "Delivery access paused" : unlocked ? "Ready to receive" : paid ? "Payment received" : "Preview collection"}</span>
        <button className="text-button" onClick={() => void refresh()} disabled={refreshing || !!busy}><span className={refreshing ? "refresh-icon spinning" : "refresh-icon"}>↻</span> {refreshing ? "Refreshing…" : "Refresh status"}</button>
      </div></section>
      {(notice || failure) && <div className="notice" role="status">{notice || failure?.message}</div>}
      <div className="workspace-grid">
        <div className="collection"><section className="section-heading"><div><div className="eyebrow">THE COLLECTION</div><h2>A first look.</h2></div><span className="small muted">{data.project.media.length} {data.project.media.length === 1 ? "file" : "files"}</span></section>
          {data.project.deliverables.length > 0 && <div className="deliverables">{data.project.deliverables.map((item) => <span key={item.id}>{item.expectedQuantity} × {item.title}</span>)}</div>}
          <div className="media-grid">{data.project.media.map((media, index) => <article className="media-card" key={media.id}>
            <div className={`preview preview-${index % 3}`}>
              <MediaPreview media={media} />
              <span className="preview-tag">PREVIEW</span>
            </div><div className="media-info"><div><h3 title={media.filename}>{media.filename}</h3><span className="small muted">{fileSize(media.sizeBytes)} · {media.status === "VERIFIED" ? "Verified" : media.status === "INVALID" ? "Needs attention" : "Preparing"}</span></div>
              {unlocked && media.status === "VERIFIED" ? <button className="download-button" aria-label={`Download ${media.filename}`} disabled={!!busy} onClick={() => void download(media.id)}>{busy === media.id ? "…" : "↓"}</button> : <span className="locked-file" aria-label="Original file locked"><Lock /></span>}
            </div>
          </article>)}</div>
          {data.project.media.length === 0 && <div className="empty-collection"><span>◈</span><h3>Something good is on its way.</h3><p>Your creator is preparing the collection. Refresh to check for new files.</p></div>}
          <div className="delivery-note"><div className="note-icon">{unlocked ? "✓" : <Lock />}</div><div><h3>{revoked ? "Delivery access is paused." : unlocked ? "Your final files are ready." : paid ? "Payment received. Finishing touches next." : "The preview is just the beginning."}</h3><p>{revoked ? "Your creator has revoked access to the originals. Contact them for help with this delivery." : unlocked ? "Use the download arrow beside each file to receive your original. Each link is authorized when you request it." : paid ? "Your creator will release the originals once every deliverable is verified. Refresh to check delivery status." : "Original files become available after verified payment and your creator’s final delivery release."}</p></div></div>
        </div>
        <aside className="invoice-card"><div className="eyebrow">PROJECT INVOICE</div><div className="invoice-heading"><h2>The details.</h2><span className={`invoice-state ${paid ? "positive" : ""}`}>{paid ? "Paid" : invoice?.status === "ISSUED" ? "Pending" : invoice?.status === "VOID" ? "Void" : "Preparing"}</span></div>
          {invoice ? <><div className="invoice-meta"><span>{invoice.invoiceNumber}</span><span>{paid ? `Paid ${date(invoice.paidAt)}` : invoice.dueAt ? `Due ${date(invoice.dueAt)}` : "No due date"}</span></div>
            <div className="line-items">{invoice.items.map((item) => <div className="line-item" key={item.id}><div><span>{item.description}</span><small>{item.quantity} × {money(item.unitPriceMinor, invoice.currency)}</small></div><strong>{money(item.lineTotalMinor, invoice.currency)}</strong></div>)}</div>
            <div className="invoice-total"><span>Total <small>{invoice.currency}</small></span><strong>{money(invoice.totalMinor, invoice.currency)}</strong></div>
            {invoice.status === "ISSUED" ? <><button className="button primary" disabled={!!busy} onClick={() => void checkout()}>{busy === "checkout" ? "Opening checkout…" : "Continue to payment"}<span>↗</span></button><p className="payment-help">Secure checkout. Payment is confirmed by the provider before files are released.</p></> : <div className="payment-confirmation">{paid ? "✓ Payment confirmed" : invoice.status === "VOID" ? "This invoice has been voided." : "Your creator is preparing your invoice."}</div>}
          </> : <p className="muted">Your invoice will appear here once your creator has prepared it.</p>}
          <div className="invoice-footer"><Lock /> Private. Protected. Yours.</div>
          {data.developmentPayments && pendingSimulation && <div className="simulator"><strong>Local payment simulator</strong><p>Development only. Sends a signed simulated provider event through the API payment handler. No money is charged.</p><button className="button secondary" disabled={!!busy} onClick={() => void simulate(pendingSimulation.id)}>{busy === "simulate" ? "Processing provider event…" : "Simulate verified payment"}</button></div>}
        </aside>
      </div>
    </main>}
    <footer className="site-footer"><span>Carefully created. Reliably delivered.</span><span>Powered by <b>slate.</b></span></footer>
  </div>;
}

function Lock() {
  return <svg width="14" height="14" viewBox="0 0 20 20" fill="none" aria-hidden="true"><rect x="4.5" y="8.5" width="11" height="8" rx="2" stroke="currentColor" strokeWidth="1.4" /><path d="M7 8V6a3 3 0 0 1 6 0v2" stroke="currentColor" strokeWidth="1.4" /><path d="M10 11v3" stroke="currentColor" strokeWidth="1.4" /></svg>;
}

function MediaPreview({ media }: { media: Media }) {
  const url = media.previewURL ? safeURL(media.previewURL) : null;
  const [failedURL, setFailedURL] = useState<string | null>(null);
  if (url && failedURL !== url) return <img src={url} alt={`Preview of ${media.filename}`} referrerPolicy="no-referrer" loading="lazy" onError={() => setFailedURL(url)} />;
  return <div className="preview-placeholder"><span>{media.mimeType.startsWith("video/") ? "▶" : "◈"}</span><p>{failedURL === url && url ? "Refresh to reload preview" : media.status === "VERIFIED" ? "Preview not available" : "File being prepared"}</p></div>;
}
