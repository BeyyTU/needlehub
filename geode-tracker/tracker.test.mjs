import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Store, validate, petPayload, boardPayload } from './core.mjs';
import { httpServer } from './server.mjs';
const pet=(extra={})=>({version:1,gameId:10770110947,jobId:'server-a',kind:'pet',category:'boss',observedAt:new Date().toISOString(),fields:{Pet:'Living Gemlet',User:'WOLFSTRIKER0',Serial:45},...extra});
const board=(extra={})=>({...pet(),kind:'board',boardId:'gems',title:'Gems',scope:'global',rows:[{username:'Player_1',value:100},{username:'Player_2',value:50}],...extra});
test('boss serial deduplicates across collectors, distinct pets and serials survive',()=>{
  const store=new Store(':memory:');assert.equal(store.accept(pet()).duplicate,false);
  assert.equal(store.accept(pet({jobId:'server-b'})).duplicate,true);
  store.accept(pet({fields:{Pet:'Another Pet',User:'Player_2',Serial:45}}));
  store.accept(pet({fields:{Pet:'Living Gemlet',User:'Player_3',Serial:46}}));
  assert.equal(store.pending().length,3);store.sent(store.pending()[0].id);assert.equal(store.pending().length,2);
});
test('secret dedup uses bounded time window; later identical hatch remains',()=>{
  const store=new Store(':memory:'); const now=Date.now();
  const d=pet({category:'secret',fields:{Pet:'Inferno Colossus',User:'Player_1'}});
  store.accept(d);assert.equal(store.accept({...d,jobId:'server-b',observedAt:new Date(now+1000).toISOString()}).duplicate,true);
  assert.equal(store.accept({...d,observedAt:new Date(now+20000).toISOString()}).duplicate,false);
});
test('out-of-order board cannot replace newer data and server boards remain separate',()=>{
  const store=new Store(':memory:');store.accept(board());
  store.accept(board({observedAt:new Date(Date.now()-10000).toISOString(),rows:[{username:'Old',value:1}]}));
  assert.equal(JSON.parse(store.boards()[0].body).rows[0].value,100);
  store.accept(board({scope:'server'}));store.accept(board({scope:'server',jobId:'server-b'}));assert.equal(store.boards().length,3);
});
test('validation rejects fabricated envelope, invalid numbers, duplicate rows and future time',()=>{
  for(const data of [pet({gameId:1}),pet({observedAt:'bad'}),pet({observedAt:new Date(Date.now()+90000000).toISOString()}),board({rows:[{username:'X',value:NaN}]}),board({rows:[{username:'X',value:2},{username:'x',value:1}]})])assert.throws(()=>validate(data));
});
test('Discord output disables mentions, distinguishes scope and caps pages',()=>{
  const p=petPayload(pet());assert.deepEqual(p.allowedMentions.parse,[]);assert.match(p.embeds[0].footer.text,/Client-observed/);
  const b=boardPayload(board({scope:'server',rows:Array.from({length:55},(_,i)=>({username:'P'+i,value:55-i}))}),2);
  assert.match(b.embeds[0].footer.text,/Current server only/);assert.equal(b.embeds[0].description.split('\n').length,15);
});
test('HTTP auth, invalid captures, durable acceptance and retry dedup',async()=>{
  const store=new Store(':memory:');const key='x'.repeat(40);const server=httpServer(store,key);
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const url=`http://127.0.0.1:${server.address().port}`;
  try {
    assert.equal((await fetch(url+'/health')).status,200);
    assert.equal((await fetch(url+'/upload',{method:'POST',body:'{}'})).status,401);
    const send=body=>fetch(url+'/upload',{method:'POST',headers:{Authorization:'Bearer '+key},body:JSON.stringify(body)});
    assert.equal((await send({})).status,400);assert.equal((await send(pet())).status,202);
    assert.equal((await (await send(pet())).json()).duplicate,true);assert.equal(store.pending().length,1);
  } finally {await new Promise(resolve=>server.close(resolve));}
});
