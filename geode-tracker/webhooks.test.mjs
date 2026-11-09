import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Store } from './core.mjs';
import { webhookIdentity, webhookRoutes, startWebhookRelay } from './webhooks.mjs';
import { provisionWebhooks } from './webhook-setup.mjs';
const url='https://discord.com/api/webhooks/123/test-token';
const pet=(extra={})=>({version:1,gameId:10770110947,jobId:'test',kind:'pet',category:'boss',observedAt:new Date().toISOString(),fields:{Pet:'MiniWarden',Name:'Player',Serial:12},...extra});
const board=()=>({...pet(),kind:'board',boardId:'TopWins',title:'Top Wins',scope:'global',rows:[{username:'Player',value:10}]});
const configured=()=>{const store=new Store(':memory:');store.setWebhookConfig({enabled:true,urls:{boss:url,secret:url,board:url}});return store;};
test('webhook routes validate credentials without exposing them and respect disabled settings',()=>{
  assert.deepEqual(webhookIdentity(url+'?thread_id=456'),{id:'123',threadId:'456'});
  for(const bad of [url.replace('https:','http:'),url.replace('discord.com','example.com'),url+'?token=secret',url+'#secret'])assert.throws(()=>webhookIdentity(bad),{message:'Use a valid Discord incoming-webhook URL'});
  const store=new Store(':memory:');assert.equal(webhookRoutes(store,{}).enabled,false);
  assert.equal(webhookRoutes(store,{GEODE_WEBHOOK_URL:url}).urls.boss,url);
  assert.equal(webhookRoutes(store,{GEODE_WEBHOOK_URL:url}).enabled,true);
  store.setWebhookConfig({enabled:false,urls:{}});assert.equal(webhookRoutes(store,{GEODE_WEBHOOK_URL:url}).enabled,false);
});
test('webhook pets retain portraits, suppress secrets and deliver only once',async()=>{
  const store=configured(),posts=[];store.accept(pet());store.accept(pet({category:'secret'}));
  const relay=startWebhookRelay(store,{env:{},scheduler:false,images:{forPet:async()=> 'https://example.com/pet.png'},clientFactory:()=>({send:async p=>{posts.push(p);return {id:'message'};}})});
  await relay.flush();await relay.flush();assert.equal(posts.length,1);assert.equal(store.pending().length,0);
  assert.equal(posts[0].embeds[0].thumbnail.url,'https://example.com/pet.png');assert.deepEqual(posts[0].allowedMentions.parse,[]);relay.stop();
});
test('failed webhook delivery releases its claim for retry',async()=>{
  const store=configured();store.accept(pet());let fail=true;
  const relay=startWebhookRelay(store,{env:{},scheduler:false,report:()=>{},clientFactory:()=>({send:async()=>{if(fail)throw Error('network');return {id:'ok'};}})});
  await relay.flush();assert.equal(store.pending().length,1);fail=false;await relay.flush();assert.equal(store.pending().length,0);relay.stop();
});
test('pet claims prevent concurrent transports and mode changes release pending events',async()=>{
  const store=configured();store.accept(pet());const id=store.pending()[0].id;
  assert.equal(store.claimPet(id),true);assert.equal(store.claimPet(id),false);store.releasePet(id);
  let ready;const pending=new Promise(resolve=>ready=resolve);let posts=0;
  const relay=startWebhookRelay(store,{env:{},scheduler:false,images:{forPet:async()=>{await pending;}},clientFactory:()=>({send:async()=>{posts++;return {id:'ok'};}})});
  const flushing=relay.flush();assert.equal(store.pending().length,0);
  store.setWebhookConfig({enabled:false,urls:{}});ready();await flushing;
  assert.equal(posts,0);assert.equal(store.pending().length,1);relay.stop();
});
test('webhook boards edit their own persisted messages and recover deleted messages',async()=>{
  const store=configured();store.accept(board());store.db.prepare('UPDATE boards SET message=?').run('bot-message');
  let sent=0,edited=0,deleted=false;
  const client={send:async()=>({id:'hook-'+(++sent)}),editMessage:async id=>{edited++;if(deleted)throw {code:10008};return {id};}};
  let relay=startWebhookRelay(store,{env:{},scheduler:false,clientFactory:()=>client});
  await relay.flush();await relay.flush();assert.equal(sent,1);assert.equal(edited,0);relay.stop();
  relay=startWebhookRelay(store,{env:{},scheduler:false,clientFactory:()=>client});await relay.flush();assert.equal(edited,1);assert.equal(sent,1);
  deleted=true;relay.configurationChanged();await relay.flush();assert.equal(sent,2);assert.equal(store.boards()[0].message,'bot-message');relay.stop();
});
function setupFixture({denied=false,existing=false}={}) {
  let created=0;const hook={name:'Geode Tracker',owner:{id:'bot'},url};
  const channel={guildId:'guild',permissionsFor:()=>({has:()=>!denied}),fetchWebhooks:async()=>({find:predicate=>existing&&predicate(hook)?hook:undefined}),createWebhook:async()=>{created++;return hook;}};
  return {guild:{id:'guild',members:{me:{}},channels:{fetch:async()=>channel}},channels:{boss:'channel',secret:'channel',board:'channel'},count:()=>created};
}
test('webhook setup checks permissions, reuses owned hooks and shares same-channel hooks',async()=>{
  const denied=setupFixture({denied:true});await assert.rejects(provisionWebhooks({...denied,botId:'bot'}),/Manage Webhooks/);assert.equal(denied.count(),0);
  const shared=setupFixture();const config=await provisionWebhooks({...shared,botId:'bot'});assert.equal(shared.count(),1);assert.deepEqual(config.urls,{boss:url,secret:url,board:url});
  const reused=setupFixture({existing:true});await provisionWebhooks({...reused,botId:'bot'});assert.equal(reused.count(),0);
  const foreign=setupFixture({existing:true});await provisionWebhooks({...foreign,botId:'other-bot'});assert.equal(foreign.count(),1);
});
