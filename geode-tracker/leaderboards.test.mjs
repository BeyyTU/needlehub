import { test } from 'node:test';
import assert from 'node:assert/strict';
import { allLeaderboardsPayload } from './leaderboards.mjs';
import { beginCommand } from './commands.mjs';
const ids=['TopMiners','DeepestEndless','FastestHard','FastestEscapes','TopWins'];
const board=id=>({scope:'global',boardId:id,title:id,format:'display',jobId:'server-a',observedAt:'2026-11-09T03:46:00Z',rows:Array.from({length:10},(_,i)=>({rank:i+1,label:'Player_'+i,displayValue:id.startsWith('Fastest')?'0:07':'1,110'}))});
test('all five global boards are returned in one message payload, with scores and observation timestamps',()=>{
  const payload=allLeaderboardsPayload(ids.map(id=>({body:JSON.stringify(board(id))})).concat({body:JSON.stringify({...board('Coins'),scope:'server'})}));
  assert.equal(payload.embeds.length,5);assert.equal(payload.content,undefined);assert.deepEqual(payload.allowedMentions.parse,[]);
  for(const embed of payload.embeds){assert.equal(embed.timestamp,'2026-11-09T03:46:00Z');assert.equal(embed.description.split('\n').length,10);}
  assert.match(payload.embeds[2].description,/0:07/);assert.match(payload.embeds[4].description,/1,110/);
});
test('missing boards get honest placeholders and an entirely empty history gets a clear response',()=>{
  const payload=allLeaderboardsPayload([board('TopWins')]);assert.equal(payload.embeds.length,5);assert.match(payload.embeds[0].description,/Waiting/);
  assert.equal(payload.embeds[0].timestamp,undefined);assert.match(allLeaderboardsPayload([]).content,/No global leaderboards/);
});
test('the single message stays inside Discord embed limits for long team names and values',()=>{
  const records=ids.map(id=>({...board(id),title:'T'.repeat(100),rows:Array.from({length:100},(_,i)=>({rank:i+1,label:'P'.repeat(100),displayValue:'9'.repeat(60)}))}));
  const payload=allLeaderboardsPayload(records);
  const length=payload.embeds.reduce((n,e)=>n+e.title.length+e.description.length+e.footer.text.length,0);
  assert.ok(length<=6000);assert.equal(payload.embeds.length,5);
});
test('both leaderboard command names acknowledge publicly so everyone can see the single reply',async()=>{
  for(const commandName of ['leaderboards','geode-leaderboards']) {
    let acknowledgement;const i={commandName,guildId:'123',isChatInputCommand:()=>true,deferReply:async opts=>{acknowledgement=opts;}};
    assert.equal(await beginCommand(i,{guild:'123'}),true);assert.deepEqual(acknowledgement,{});
  }
});
