import { createHash } from 'node:crypto';
import { mkdirSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import sharp from 'sharp';
import { portraitSpec, petId } from './pets.mjs';

function permitted(url) {
  const u=new URL(url);
  return u.protocol==='https:' && !u.username && !u.password && !u.port && (u.hostname==='assetdelivery.roblox.com' || u.hostname==='rbxcdn.com' || u.hostname.endsWith('.rbxcdn.com'));
}
export async function downloadAsset(assetId,fetchImpl=fetch) {
  return downloadImageUrl(`https://assetdelivery.roblox.com/v1/asset/?id=${assetId}`,fetchImpl);
}
async function downloadImageUrl(url,fetchImpl) {
  for(let i=0;i<4;i++) {
    if(!permitted(url))throw Error('Unapproved image host');
    const response=await fetchImpl(url,{redirect:'manual',signal:AbortSignal.timeout(8000)});
    if([301,302,303,307,308].includes(response.status)) {url=new URL(response.headers.get('location'),url).href;continue;}
    if(!response.ok || Number(response.headers.get('content-length')??0)>8000000)throw Error('Image unavailable');
    const chunks=[];let total=0;
    for await(const chunk of response.body) {total+=chunk.length;if(total>8000000)throw Error('Image too large');chunks.push(chunk);}
    return Buffer.concat(chunks);
  }
  throw Error('Too many redirects');
}
export async function downloadPortrait(spec,fetchImpl=fetch) {
  try {return {bytes:await downloadAsset(spec.assetId,fetchImpl),spec};}catch {
    // A whole-asset thumbnail is not a substitute for a cropped pet on a sheet.
    if(spec.width!==undefined && (!spec.sheetWidth || spec.sheetWidth!==spec.sheetHeight))throw Error('Original atlas dimensions unavailable');
    const response=await fetchImpl(`https://thumbnails.roblox.com/v1/assets?assetIds=${spec.assetId}&size=700x700&format=Png&isCircular=false`,{signal:AbortSignal.timeout(8000)});
    if(!response.ok)throw Error('Thumbnail unavailable');
    const data=await response.json();const item=data.data?.find(r=>String(r.targetId)===spec.assetId && r.state==='Completed');
    if(!item || /\/PrivateImage\//i.test(item.imageUrl??'') || !permitted(item.imageUrl))throw Error('No public thumbnail');
    const bytes=await downloadImageUrl(item.imageUrl,fetchImpl);
    if(spec.width===undefined)return {bytes,spec};
    const metadata=await sharp(bytes,{limitInputPixels:33554432}).metadata();
    if(metadata.width!==metadata.height)throw Error('Unexpected thumbnail dimensions');
    const scale=metadata.width/spec.sheetWidth;
    return {bytes,spec:{assetId:spec.assetId,x:Math.round(spec.x*scale),y:Math.round(spec.y*scale),width:Math.max(1,Math.round(spec.width*scale)),height:Math.max(1,Math.round(spec.height*scale))}};
  }
}
export async function cropPortrait(bytes,value) {
  const spec=portraitSpec(value);if(!spec)throw Error('Invalid portrait');
  let image=sharp(bytes,{limitInputPixels:33554432});
  const metadata=await image.metadata();
  if(spec.width!==undefined) {
    if(spec.x+spec.width>metadata.width || spec.y+spec.height>metadata.height)throw Error('Portrait crop exceeds sheet');
    image=image.extract({left:spec.x,top:spec.y,width:spec.width,height:spec.height});
  }
  return image.resize(256,256,{fit:'contain',background:{r:0,g:0,b:0,alpha:0}}).png().toBuffer();
}
export class PetImages {
  constructor(directory,baseUrl,{fetchImpl=fetch,bundledDirectory=join(import.meta.dirname,'assets','boss')}={}) {
    this.directory=directory;this.bundledDirectory=bundledDirectory;this.baseUrl=baseUrl.replace(/\/$/,'');this.fetchImpl=fetchImpl;this.pending=new Map();this.failures=new Map();
    mkdirSync(directory,{recursive:true});
  }
  async forPet(d,store) {
    const id=petId(d);
    if(typeof id==='string' && /^[A-Za-z0-9_-]{1,80}$/.test(id) && existsSync(join(this.bundledDirectory,id+'.png')))return `${this.baseUrl}/boss-pets/${id}.png`;
    const metadata=store.petInfo(petId(d))??d.pet;
    const spec=portraitSpec(metadata?.portrait);if(!spec)return undefined;
    const digest=createHash('sha256').update('portrait-v2:'+JSON.stringify(spec)).digest('hex');
    const file=join(this.directory,digest+'.png');
    if(!existsSync(file)) {
      if((this.failures.get(digest)??0)>Date.now())return undefined;
      if(!this.pending.has(digest))this.pending.set(digest,(async()=>{
        const result=await downloadPortrait(spec,this.fetchImpl);
        writeFileSync(file,await cropPortrait(result.bytes,result.spec));
      })().finally(()=>this.pending.delete(digest)));
      try {await this.pending.get(digest);}catch {this.failures.set(digest,Date.now()+60000);return undefined;}
    }
    return `${this.baseUrl}/pet-images/${digest}.png`;
  }
  serve(path,res) {
    const boss=/^\/boss-pets\/([A-Za-z0-9_-]{1,80})\.png$/.exec(path);
    if(boss) {
      const file=join(this.bundledDirectory,boss[1]+'.png');if(!existsSync(file))return false;
      const bytes=readFileSync(file);res.writeHead(200,{'Content-Type':'image/png','Content-Length':bytes.length,'Cache-Control':'public, max-age=86400','X-Content-Type-Options':'nosniff'});res.end(bytes);return true;
    }
    const match=/^\/pet-images\/([a-f0-9]{64})\.png$/.exec(path);
    if(!match)return false;
    const file=join(this.directory,match[1]+'.png');if(!existsSync(file))return false;
    const bytes=readFileSync(file);res.writeHead(200,{'Content-Type':'image/png','Content-Length':bytes.length,'Cache-Control':'public, max-age=86400','X-Content-Type-Options':'nosniff'});res.end(bytes);return true;
  }
}
