import { createServer } from 'node:http';
import { timingSafeEqual } from 'node:crypto';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { Store } from './core.mjs';
export function httpServer(store,key,{images,onAccepted}={}) {
  const expected=Buffer.from('Bearer '+key);
  return createServer(async(req,res)=>{
    const reply=(code,data)=>{res.writeHead(code,{'Content-Type':'application/json'});res.end(JSON.stringify(data));};
    if(req.method==='GET' && req.url==='/health') return reply(200,{status:'ready'});
    if(req.method==='GET' && images?.serve(req.url,res))return;
    if(req.method!=='POST' || req.url!=='/upload') return reply(404,{error:'not found'});
    const supplied=Buffer.from(req.headers.authorization??'');
    if(supplied.length!==expected.length || !timingSafeEqual(supplied,expected)) return reply(401,{error:'unauthorized'});
    let bytes=0; const chunks=[];
    try {
      for await(const chunk of req) {bytes+=chunk.length;if(bytes>256000){reply(413,{error:'too large'});req.destroy();return;}chunks.push(chunk);}
      const data=JSON.parse(Buffer.concat(chunks).toString('utf8'));
      const result=store.accept(data);
      reply(202,result);
      if(['pet','board','refresh'].includes(data.kind))onAccepted?.();
    } catch {if(!res.headersSent)reply(400,{error:'invalid capture'});}
  });
}
if(process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href) {
  const key=process.env.GEODE_UPLOAD_KEY??'';
  if(key.length<32) throw Error('Set GEODE_UPLOAD_KEY to at least 32 random characters');
  const dir=process.env.TRACKER_DATA_DIR??'./data';mkdirSync(dir,{recursive:true});
  const store=new Store(join(dir,'geode.sqlite'));
  const {PetImages}=await import('./images.mjs');
  const base=process.env.GEODE_PUBLIC_URL??('https://'+(process.env.RAILWAY_PUBLIC_DOMAIN??'geode-tracker-production.up.railway.app'));
  const images=new PetImages(join(dir,'pet-images'),base);
  const {startBot}=await import('./bot.mjs');
  const client=await startBot(store,{images});
  const server=httpServer(store,key,{images,onAccepted:()=>client.requestDelivery()}); server.requestTimeout=15000;server.headersTimeout=10000;
  server.listen(Number(process.env.PORT??8080),'0.0.0.0',()=>console.log('Geode tracker listening'));
  for(const signal of ['SIGINT','SIGTERM'])process.on(signal,()=>{server.close();client.destroy();process.exit(0);});
}
