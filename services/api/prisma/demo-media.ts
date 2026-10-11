import 'dotenv/config';
import { readFile } from 'node:fs/promises';
import { randomUUID,createHash } from 'node:crypto';
import sharp from 'sharp';
if(process.env.NODE_ENV==='production'||process.env.DEVELOPMENT_PAYMENTS!=='true') throw new Error('Demo media setup is development-only');
const base=process.env.API_PUBLIC_URL??'http://localhost:3000';
let token='';
async function api(method:string,path:string,body?:unknown) { const response=await fetch(base+path,{method,headers:{...(token?{Authorization:'Bearer '+token}:{}),'Content-Type':'application/json','Idempotency-Key':randomUUID()},body:body!==undefined?JSON.stringify(body):undefined}); const json:any=await response.json(); if(!response.ok) throw new Error(`${path}: ${response.status} ${json.error}`); return json; }
const login=await api('POST','/auth/login',{email:'demo@slate.local',password:'SlateDemo2026!'});token=login.token;
const projects=await api('GET','/projects');
const p=projects.find((p:any)=>p.invoice?.invoiceNumber==='SL-DEMO-001');if(!p) throw new Error('Run db:seed first');
let media=p.media.find((m:any)=>m.filename==='campaign-study.jpg'&&m.status==='VERIFIED');
if(!media) { const bytes=await sharp(await readFile(new URL('../test/fixtures/demo-campaign.svg',import.meta.url))).jpeg({quality:88}).toBuffer(); const t=await api('POST','/transfers',{projectId:p.id,filename:'campaign-study.jpg',mimeType:'image/jpeg',sizeBytes:bytes.length,contentHash:createHash('sha256').update(bytes).digest('hex')}); const {url}=await api('POST',`/transfers/${t.id}/parts/1/sign`,{}); const upload=await fetch(url,{method:'PUT',body:new Uint8Array(bytes)}); if(!upload.ok) throw new Error('Demo upload failed'); media=(await api('POST',`/transfers/${t.id}/complete`,{})).mediaAsset; }
if(p.invoice.status==='PAID') await api('POST',`/projects/${p.id}/delivery/release`,{});
const share=await api('POST',`/projects/${p.id}/share`,{});
console.log(JSON.stringify({projectId:p.id,mediaAssetId:media.id,url:share.url,status:p.invoice.status==='PAID'?'RELEASED':'LOCKED',fixture:'Generated campaign illustration; not a photograph'}));
await api('POST','/auth/logout',{});
