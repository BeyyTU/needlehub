import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Store } from './core.mjs';
const board=(extra={})=>({version:1,gameId:10770110947,jobId:'server-a',kind:'board',observedAt:new Date().toISOString(),boardId:'TopWins',title:'Top Wins',scope:'global',format:'display',rows:[{rank:1,label:'Player_1',displayValue:'1,110'}],...extra});
const refresh=(requestId,snapshots=[])=>({...board(),kind:'refresh',requestId,snapshots});
test('each execution queues a new leaderboard post even when scores are unchanged',()=>{
  const store=new Store(':memory:');store.accept(refresh('execution-00000001',[board()]));
  let post=store.pendingBoardPosts()[0];store.boardPostSent(post,'message-1');
  store.accept(refresh('execution-00000002',[board()]));post=store.pendingBoardPosts()[0];
  assert.equal(store.pendingBoardPosts().length,1);assert.equal(post.request,'execution-00000002');
  store.boardPostSent(post,'message-2');assert.equal(store.boards()[0].message,'message-2');
});
test('retrying a refresh upload never creates a second post job',()=>{
  const store=new Store(':memory:');const data=refresh('execution-00000001',[board()]);
  store.accept(data);const id=store.pendingBoardPosts()[0].id;
  assert.equal(store.accept(data).duplicate,true);assert.equal(store.pendingBoardPosts().length,1);
  store.boardPostSent(store.pendingBoardPosts()[0],'message-1');store.accept(data);
  assert.equal(store.pendingBoardPosts().length,0);assert.equal(store.db.prepare('SELECT id FROM board_posts').get().id,id);
});
test('fresh captured scores are stored before the execution resend is queued',()=>{
  const store=new Store(':memory:');store.accept(board({observedAt:new Date(Date.now()-10000).toISOString(),rows:[{rank:1,label:'Player_1',displayValue:'900'}]}));
  store.accept(refresh('execution-00000001',[board()]));
  assert.equal(JSON.parse(store.pendingBoardPosts()[0].body).rows[0].displayValue,'1,110');
});
test('a run place resends the last known global board without changing its observation time or including server-only stats',()=>{
  const store=new Store(':memory:');const observedAt=new Date(Date.now()-10000).toISOString();
  store.accept(board({observedAt}));store.accept(board({boardId:'Coins',scope:'server'}));
  const result=store.accept(refresh('execution-00000001'));
  assert.equal(result.queued,1);assert.equal(JSON.parse(store.pendingBoardPosts()[0].body).observedAt,observedAt);
});
test('queued execution resends survive a service restart, and normal polling does not queue extra posts',()=>{
  const dir=mkdtempSync(join(tmpdir(),'geode-refresh-'));try {
    let store=new Store(join(dir,'test.sqlite'));store.accept(refresh('execution-00000001',[board()]));store.db.close();
    store=new Store(join(dir,'test.sqlite'));assert.equal(store.pendingBoardPosts().length,1);
    store.accept(board());store.accept(board());assert.equal(store.pendingBoardPosts().length,1);store.db.close();
  }finally{rmSync(dir,{recursive:true,force:true});}
});
