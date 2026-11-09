import { test } from 'node:test';
import assert from 'node:assert/strict';
import { beginCommand, guildAllowed } from './commands.mjs';

function interaction(extra={}) {
  const calls=[];
  return {calls,commandName:'geode-setup',guildId:'123',isChatInputCommand:()=>true,
    deferReply:async()=>calls.push('ack'),editReply:async data=>calls.push(data.content),...extra};
}
test('setup acknowledges before guild cache or permission checks, including missing cache',async()=>{
  const i=interaction({guild:null});assert.equal(await beginCommand(i,{}),true);assert.deepEqual(i.calls,['ack']);
});
test('wrong server gets an acknowledged explanation instead of silently timing out',async()=>{
  const i=interaction();assert.equal(await beginCommand(i,{guild:'456'}),false);assert.equal(i.calls[0],'ack');assert.match(i.calls[1],/different server/);
});
test('DM command gets an acknowledged explanation',async()=>{
  const i=interaction({guildId:null});assert.equal(await beginCommand(i,{}),false);assert.equal(i.calls[0],'ack');assert.match(i.calls[1],/inside your Discord server/);
});
test('name matching tolerates decoration; configured server ID remains authoritative',()=>{
  assert.equal(guildAllowed({id:'123',name:'Jhit Inc. 💎'}, {}, 'jhit inc'),true);
  assert.equal(guildAllowed({id:'123',name:' jhit   inc '}, {}, 'jhit inc'),true);
  assert.equal(guildAllowed({id:'123',name:'Other Server'}, {}, 'jhit inc'),false);
  assert.equal(guildAllowed({id:'123',name:'Renamed'}, {guild:'123'}, 'jhit inc'),true);
  assert.equal(guildAllowed({id:'456',name:'jhit inc'}, {guild:'123'}, 'jhit inc'),false);
});
test('unrelated interaction is left to its own handler',async()=>{
  const i=interaction({commandName:'unrelated'});assert.equal(await beginCommand(i,{}),false);assert.deepEqual(i.calls,[]);
});
