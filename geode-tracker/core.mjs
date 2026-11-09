import { createHash } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { petMetadata, petId, displayPetName } from './pets.mjs';
const text = (v, max=100) => typeof v === 'string' && v.trim() && v.length<=max && !/[\x00-\x1f]/.test(v);
const scalar = v => ['string','number','boolean'].includes(typeof v) && String(v).length<=150;
export function validate(d, now=Date.now()) {
  if (!d || d.version!==1 || d.gameId!==10770110947 || !text(d.jobId,100) || !['pet','board','catalog'].includes(d.kind)) throw Error('Invalid envelope');
  const time=Date.parse(d.observedAt);
  if (!Number.isFinite(time) || Math.abs(now-time)>86400000) throw Error('Observation must be within 24 hours');
  if(d.kind==='catalog') {
    if(!Array.isArray(d.pets) || !d.pets.length || d.pets.length>1000 || d.pets.some(p=>!petMetadata(p)))throw Error('Invalid pet catalog');
  } else if (d.kind==='pet') {
    if (!['boss','secret'].includes(d.category) || !d.fields || typeof d.fields!=='object' || Array.isArray(d.fields)) throw Error('Invalid pet');
    if (JSON.stringify(d.fields).length>10000) throw Error('Fields too large');
    const pet=d.fields.Pet;
    const name=typeof pet==='object' && pet ? pet.Name ?? pet.name : pet;
    if (!scalar(name) && !scalar(d.fields.Name)) throw Error('Pet name not understood; export capture');
  } else {
    if (!text(d.boardId,160) || !text(d.title,100) || !['server','global'].includes(d.scope) || !Array.isArray(d.rows) || !d.rows.length || d.rows.length>1000) throw Error('Invalid board');
    const ids=new Set(); let prev=Infinity,previousRank=0;
    for (const r of d.rows) {
      if(d.format==='display') {
        if(!r || !Number.isSafeInteger(r.rank) || r.rank<1 || r.rank<previousRank || !text(r.label,100) || !text(r.displayValue,60) || ids.has(`${r.rank}:${r.label}`))throw Error('Invalid displayed board rows');
        ids.add(`${r.rank}:${r.label}`);previousRank=r.rank;continue;
      }
      if (!r || !text(r.username,30) || !/^[A-Za-z0-9_]+$/.test(r.username) || !Number.isSafeInteger(r.value) || r.value<0 || r.value>prev || ids.has(r.username.toLowerCase())) throw Error('Invalid or unsorted rows');
      ids.add(r.username.toLowerCase()); prev=r.value;
    }
  }
  return d;
}
const hash = s => createHash('sha256').update(s).digest('hex');
function stable(v) {
  if (Array.isArray(v)) return v.map(stable);
  if (v && typeof v==='object') return Object.fromEntries(Object.keys(v).sort().map(k=>[k,stable(v[k])]));
  return v;
}
export class Store {
  constructor(path) {
    this.db=new DatabaseSync(path);
    this.db.exec(`PRAGMA journal_mode=WAL; CREATE TABLE IF NOT EXISTS pets(id TEXT PRIMARY KEY, fingerprint TEXT, at INTEGER, body TEXT, sent INTEGER DEFAULT 0);
      CREATE INDEX IF NOT EXISTS pet_fingerprint ON pets(fingerprint,at);
      CREATE TABLE IF NOT EXISTS boards(id TEXT PRIMARY KEY, at INTEGER, body TEXT, message TEXT);
      CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY,value TEXT);`);
    this.db.exec('CREATE TABLE IF NOT EXISTS pet_catalog(id TEXT PRIMARY KEY, body TEXT)');
  }
  settings() {const row=this.db.prepare('SELECT value FROM meta WHERE key=?').get('pet-settings');return {showSecrets:false,...(row?JSON.parse(row.value):{})};}
  setSettings(update) {
    if(typeof update.showSecrets!=='boolean')throw Error('showSecrets must be a boolean');
    const settings={showSecrets:update.showSecrets};
    this.db.prepare('INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value').run('pet-settings',JSON.stringify(settings));
    if(!settings.showSecrets)this.suppressSecrets();return settings;
  }
  suppressSecrets() {this.db.prepare("UPDATE pets SET sent=2 WHERE sent=0 AND json_extract(body,'$.category')='secret'").run();}
  rememberPet(value) {
    const metadata=petMetadata(value);if(!metadata)return;
    const previous=this.petInfo(metadata.id)??{};
    this.db.prepare('INSERT INTO pet_catalog(id,body) VALUES(?,?) ON CONFLICT(id) DO UPDATE SET body=excluded.body').run(metadata.id,JSON.stringify({...previous,...metadata}));
  }
  petInfo(id) {const row=typeof id==='string'?this.db.prepare('SELECT body FROM pet_catalog WHERE id=?').get(id):null;return row?JSON.parse(row.body):null;}
  accept(d) {
    validate(d); const at=Date.parse(d.observedAt);
    if(d.kind==='catalog') {for(const p of d.pets)this.rememberPet(p);return {accepted:true};}
    if(d.kind==='board') {
      const id=d.scope==='server'?`${d.jobId}:${d.boardId}`:d.boardId;
      this.db.prepare(`INSERT INTO boards(id,at,body) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET at=excluded.at,body=excluded.body WHERE excluded.at>boards.at`).run(id,at,JSON.stringify({...d,storageId:id}));
      return {accepted:true};
    }
    const f=d.fields;
    if(d.pet?.id===petId(d))this.rememberPet(d.pet);
    const fingerprint=hash(JSON.stringify(stable({category:d.category,fields:f})));
    const serial=d.category==='boss' && scalar(f.Serial)?String(f.Serial):null;
    // Serial is per pet, not across all bosses. No-serial observations use a short window.
    const id=serial?hash(JSON.stringify(stable({category:d.category,pet:f.Pet??f.Name,serial}))):hash(`${fingerprint}:${at}:${d.jobId}`);
    if(!serial && this.db.prepare('SELECT 1 FROM pets WHERE fingerprint=? AND at BETWEEN ? AND ?').get(fingerprint,at-15000,at+15000)) return {accepted:true,duplicate:true};
    const state=d.category==='secret' && !this.settings().showSecrets?2:0;
    const result=this.db.prepare('INSERT OR IGNORE INTO pets(id,fingerprint,at,body,sent) VALUES(?,?,?,?,?)').run(id,fingerprint,at,JSON.stringify(d),state);
    return {accepted:true,duplicate:result.changes===0};
  }
  pending() {return this.db.prepare('SELECT * FROM pets WHERE sent=0 ORDER BY at LIMIT 10').all();}
  sent(id) {this.db.prepare('UPDATE pets SET sent=1 WHERE id=?').run(id);}
  boards() {return this.db.prepare('SELECT * FROM boards ORDER BY at DESC LIMIT 100').all();}
  recent(category,limit=10) {return this.db.prepare('SELECT body FROM pets WHERE json_extract(body,\'$.category\')=? ORDER BY at DESC LIMIT ?').all(category,limit).map(r=>JSON.parse(r.body));}
  stats() {return this.db.prepare('SELECT json_extract(body,\'$.category\') category,COUNT(*) count FROM pets GROUP BY category').all();}
}
export const clean = v => String(v??'Unknown').replace(/[`*_~|<>\\]/g,'').slice(0,150);
export function petPayload(d,{metadata,thumbnail}={}) {
  const f=d.fields;
  const candidates=[f.Name,typeof f.User==='object'?f.User?.Name??f.User?.Username:f.User];
  const player=candidates.find(v=>typeof v==='string' && /^[A-Za-z0-9_]{1,30}$/.test(v) && !/^\d+$/.test(v));
  const fields=[];
  if(d.category==='boss' && /^\d{1,20}$/.test(String(f.Serial??'')))fields.push({name:'Discovery',value:'#'+f.Serial,inline:true});
  if(typeof f.Odds==='string' && f.Odds.trim())fields.push({name:'Odds',value:clean(f.Odds),inline:true});
  return {allowedMentions:{parse:[]},embeds:[{author:{name:d.category==='boss'?'Boss pet found':'Secret pet hatched'},title:clean(displayPetName(petId(d),metadata??d.pet)),color:d.category==='boss'?0xE4B565:0xA788E8,
    ...(player?{description:`${d.category==='boss'?'Found':'Hatched'} by \`${player}\``}:{}),
    ...(fields.length?{fields}:{}),...(thumbnail?{thumbnail:{url:thumbnail}}:{}),timestamp:d.observedAt,
    footer:{text:'Crack the Geode • Observed in-game'}}]};
}
export function boardPayload(d,page=0) {
  const pages=Math.ceil(d.rows.length/20); page=Math.max(0,Math.min(page,pages-1));
  const label=v=>'`'+String(v).replace(/[`\r\n]/g,'').slice(0,100)+'`';
  return {allowedMentions:{parse:[]},embeds:[{title:clean(d.title),description:d.rows.slice(page*20,page*20+20).map((r,i)=>d.format==='display'?`**${r.rank}.** ${label(r.label)} — ${clean(r.displayValue)}`:`**${page*20+i+1}.** ${label(r.username)} — ${r.value.toLocaleString('en-US')}`).join('\n'),color:0x48B89A,timestamp:d.observedAt,
    footer:{text:`${d.scope==='global'?'Observed global board':'Current server only'} • Page ${page+1}/${pages} • ${d.rows.length} loaded rows${d.format==='display'?' • As displayed in-game; active view':''}${d.scope==='server'?' • '+d.jobId.slice(0,8):''}`}}]};
}
