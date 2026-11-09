import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Store } from './core.mjs';
const board=(extra={})=>({version:1,gameId:10770110947,jobId:'server-a',kind:'board',observedAt:new Date().toISOString(),boardId:'TopWins',title:'Top Wins',scope:'global',format:'display',rows:[{rank:1,label:'Player_1',displayValue:'1,110'}],...extra});
const refresh=(requestId,snapshots=[])=>({...board(),kind:'refresh',requestId,snapshots});
test('each execution refreshes existing leaderboard messages without queueing a resend',()=>{
  const store=new Store(':memory:');store.accept(board());
  store.db.prepare('UPDATE boards SET message=?').run('original-message');
  store.accept(refresh('execution-00000001',[board()]));assert.equal(store.boardRefreshRevision(),'execution-00000001');
  store.accept(refresh('execution-00000002',[board()]));
  assert.equal(store.pendingBoardPosts().length,0);assert.equal(store.boardRefreshRevision(),'execution-00000002');assert.equal(store.boards()[0].message,'original-message');
});
test('retrying a refresh upload is idempotent and never queues post jobs',()=>{
  const store=new Store(':memory:');const data=refresh('execution-00000001',[board()]);
  store.accept(data);assert.equal(store.accept(data).duplicate,true);assert.equal(store.pendingBoardPosts().length,0);assert.equal(store.boardRefreshRevision(),data.requestId);
});
test('fresh captured scores replace the snapshot while retaining the existing Discord message ID',()=>{
  const store=new Store(':memory:');store.accept(board({observedAt:new Date(Date.now()-10000).toISOString(),rows:[{rank:1,label:'Player_1',displayValue:'900'}]}));
  store.accept(refresh('execution-00000001',[board()]));
  assert.equal(JSON.parse(store.boards()[0].body).rows[0].displayValue,'1,110');assert.equal(store.pendingBoardPosts().length,0);
});
test('a run place refresh keeps the last global observation time',()=>{
  const store=new Store(':memory:');const observedAt=new Date(Date.now()-10000).toISOString();
  store.accept(board({observedAt}));store.accept(board({boardId:'Coins',scope:'server'}));
  const result=store.accept(refresh('execution-00000001'));
  assert.equal(result.updated,1);assert.equal(JSON.parse(store.boards().find(r=>r.id==='TopWins').body).observedAt,observedAt);
});
test('refresh revision survives restart; pending legacy reposts are cancelled without removing leaderboard messages',()=>{
  const dir=mkdtempSync(join(tmpdir(),'geode-refresh-'));try {
    let store=new Store(join(dir,'test.sqlite'));store.accept(refresh('execution-00000001',[board()]));
    store.db.prepare('UPDATE boards SET message=?').run('original-message');
    store.db.prepare('INSERT INTO board_posts(id,request,board_id,body,at) VALUES(?,?,?,?,?)').run('legacy-post','legacy-execution','TopWins',JSON.stringify(board()),Date.now());store.db.close();
    store=new Store(join(dir,'test.sqlite'));store.cancelPendingBoardPosts();assert.equal(store.pendingBoardPosts().length,0);
    assert.equal(store.boardRefreshRevision(),'execution-00000001');assert.equal(store.boards()[0].message,'original-message');store.db.close();
  }finally{rmSync(dir,{recursive:true,force:true});}
});
