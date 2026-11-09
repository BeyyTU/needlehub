import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createDeliveryScheduler } from './delivery.mjs';
import { Store, boardPayload } from './core.mjs';
import { httpServer } from './server.mjs';
import { allLeaderboardsPayload } from './leaderboards.mjs';
function deferred(){let resolve;const promise=new Promise(r=>{resolve=r;});return {promise,resolve};}
async function deadline(promise){let timer;try{return await Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Immediate delivery did not wake')),1500);})]);}finally{clearTimeout(timer);}}
test('a new upload wakes delivery without waiting for the safety poll and bursts are coalesced',async()=>{
  const done=deferred();let calls=0;
  const scheduler=createDeliveryScheduler(async()=>{calls++;done.resolve();},{delayMs:1,safetyMs:60000});
  try{for(let i=0;i<20;i++)scheduler.request();await deadline(done.promise);assert.equal(calls,1);}finally{scheduler.stop();}
});
test('an event arriving during delivery gets another immediate pass without overlapping sends',async()=>{
  const started=deferred(),release=deferred(),finished=deferred();let calls=0,active=0,maxActive=0;
  const scheduler=createDeliveryScheduler(async()=>{
    active++;maxActive=Math.max(maxActive,active);calls++;
    try{if(calls===1){started.resolve();await release.promise;}else finished.resolve();}finally{active--;}
  },{delayMs:1,safetyMs:60000});
  try{scheduler.request();await deadline(started.promise);scheduler.request();release.resolve();await deadline(finished.promise);assert.equal(calls,2);assert.equal(maxActive,1);}finally{release.resolve();scheduler.stop();}
});
test('authenticated pet uploads notify delivery immediately; rejected uploads do not',async()=>{
  const store=new Store(':memory:');const key='x'.repeat(40);let notifications=0;
  const server=httpServer(store,key,{onAccepted:()=>{notifications++;}});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const url=`http://127.0.0.1:${server.address().port}/upload`;
  try {
    await fetch(url,{method:'POST',body:'{}'});assert.equal(notifications,0);
    await fetch(url,{method:'POST',headers:{Authorization:'Bearer '+key},body:'{}'});assert.equal(notifications,0);
    const response=await fetch(url,{method:'POST',headers:{Authorization:'Bearer '+key},body:JSON.stringify({version:1,gameId:10770110947,jobId:'test-server',kind:'pet',category:'boss',observedAt:new Date().toISOString(),fields:{Pet:'MiniAnvil',Name:'Player',Serial:1}})});
    assert.equal(response.status,202);assert.equal(notifications,1);assert.equal(store.pending().length,1);
  }finally{await new Promise(resolve=>server.close(resolve));}
});
test('global leaderboard messages omit diagnostic footers but retain viewer-local timestamps',()=>{
  const board={scope:'global',boardId:'TopWins',title:'Top Wins',format:'display',observedAt:'2026-11-09T03:46:00Z',rows:[{rank:1,label:'Player',displayValue:'1,110'}]};
  const normal=boardPayload(board).embeds[0];assert.equal(normal.footer,undefined);assert.equal(normal.timestamp,board.observedAt);
  const combined=allLeaderboardsPayload([board]);for(const embed of combined.embeds)assert.equal(embed.footer,undefined);
  assert.doesNotMatch(JSON.stringify(combined),/Observed global board|Page 1|loaded rows|active view/);
});
