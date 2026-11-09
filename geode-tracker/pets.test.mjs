import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import sharp from 'sharp';
import { Store, petPayload } from './core.mjs';
import { visibleCategory, portraitSpec } from './pets.mjs';
import { cropPortrait, downloadAsset, downloadPortrait, PetImages } from './images.mjs';
const pet=(extra={})=>({version:1,gameId:10770110947,jobId:'server-a',kind:'pet',category:'boss',observedAt:new Date().toISOString(),fields:{Pet:'MiniJewel',Name:'smirx123',User:617384939,Serial:47,Global:true},...extra});
test('clean boss message uses pet display name and username, never raw fields or numeric player ID',()=>{
  const p=petPayload(pet(),{thumbnail:'https://example.com/pet.png'});const e=p.embeds[0];
  assert.equal(e.title,'Living Gemlet');assert.equal(e.description,'Found by `smirx123`');
  assert.deepEqual(e.fields,[{name:'Discovery',value:'#47',inline:true}]);assert.equal(e.thumbnail.url,'https://example.com/pet.png');
  assert.doesNotMatch(JSON.stringify(p),/617384939|Global|raw|Announcement|UserId|Type/);
  assert.equal(petPayload(pet({fields:{Pet:'MiniJewel',User:617384939}})).embeds[0].description,undefined);
});
test('secret format is compact and keeps human-readable odds and usernames with underscores',()=>{
  const e=petPayload(pet({category:'secret',fields:{Pet:'InfernoColossus',Name:'Player_1',User:123,Odds:'1 in 30,300',Global:true,Type:'Secret'}})).embeds[0];
  assert.equal(e.title,'Inferno Colossus');assert.equal(e.description,'Hatched by `Player_1`');assert.deepEqual(e.fields,[{name:'Odds',value:'1 in 30,300',inline:true}]);
});
test('secrets default to hidden; enabling does not replay hidden events; disabling drains pending secrets only',()=>{
  const store=new Store(':memory:');assert.equal(store.settings().showSecrets,false);
  store.accept(pet({category:'secret',fields:{Pet:'Secret',Name:'Player'}}));store.accept(pet());assert.equal(store.pending().length,1);
  store.setSettings({showSecrets:true});assert.equal(store.pending().length,1);
  store.accept(pet({category:'secret',fields:{Pet:'OtherSecret',Name:'Other'}}));assert.equal(store.pending().length,2);
  store.setSettings({showSecrets:false});assert.equal(store.pending().length,1);assert.equal(store.recent('secret').length,2);
  assert.equal(visibleCategory('secret',store.settings()),false);assert.equal(visibleCategory('boss',store.settings()),true);
});
test('secret preference persists across process/database restart',()=>{
  const dir=mkdtempSync(join(tmpdir(),'geode-settings-'));try {
    const a=new Store(join(dir,'test.sqlite'));a.setSettings({showSecrets:true});a.db.close();
    const b=new Store(join(dir,'test.sqlite'));assert.equal(b.settings().showSecrets,true);b.db.close();
  }finally{rmSync(dir,{recursive:true,force:true});}
});
test('portrait catalog validates coordinates and preserves existing artwork when later metadata lacks it',()=>{
  const store=new Store(':memory:');store.accept({...pet(),kind:'catalog',pets:[{id:'MiniJewel',name:'Living Gemlet',portrait:{assetId:'123',x:0,y:0,width:32,height:32}}]});
  store.rememberPet({id:'MiniJewel',name:'Living Gemlet'});assert.equal(store.petInfo('MiniJewel').portrait.width,32);
  assert.equal(portraitSpec({assetId:'https://internal/secret'}),null);assert.equal(portraitSpec({assetId:'123',x:-1,y:0,width:32,height:32}),null);
});
test('sprite-sheet crop extracts the requested pet rather than publishing the whole atlas',async()=>{
  const source=await sharp({create:{width:64,height:32,channels:4,background:'#ff0000'}}).composite([{input:await sharp({create:{width:32,height:32,channels:4,background:'#0000ff'}}).png().toBuffer(),left:32,top:0}]).png().toBuffer();
  const result=await cropPortrait(source,{assetId:'123',x:32,y:0,width:32,height:32});
  const {data,info}=await sharp(result).raw().toBuffer({resolveWithObject:true});assert.equal(info.width,256);assert.equal(data[0],0);assert.equal(data[2],255);
  await assert.rejects(()=>cropPortrait(source,{assetId:'123',x:40,y:0,width:32,height:32}));
});
test('asset downloads reject redirects outside the Roblox image hosts',async()=>{
  let calls=0;await assert.rejects(()=>downloadAsset('123',async()=>{calls++;return new Response(null,{status:302,headers:{location:'https://127.0.0.1/private'}});}));assert.equal(calls,1);
});
test('restricted assets can use public thumbnails, but an atlas without known dimensions is never shown whole',async()=>{
  const bytes=await sharp({create:{width:32,height:32,channels:4,background:'#ffaa00'}}).png().toBuffer();
  let count=0;
  const fetchImpl=async url=>{
    count++;
    if(url.includes('assetdelivery.'))return new Response(null,{status:403});
    if(url.includes('thumbnails.'))return Response.json({data:[{targetId:123,state:'Completed',imageUrl:'https://t0.rbxcdn.com/test'}]});
    return new Response(bytes);
  };
  assert.equal((await downloadPortrait({assetId:'123'},fetchImpl)).bytes.length,bytes.length);assert.equal(count,3);
  await assert.rejects(()=>downloadPortrait({assetId:'123',x:0,y:0,width:16,height:16},fetchImpl),/dimensions unavailable/);
});
test('a completed Roblox private-image placeholder is not treated as pet artwork',async()=>{
  let calls=0;
  await assert.rejects(()=>downloadPortrait({assetId:'123'},async url=>{
    calls++;
    if(url.includes('assetdelivery.'))return new Response(null,{status:403});
    return Response.json({data:[{targetId:123,state:'Completed',imageUrl:'https://tr.rbxcdn.com/hash/700/700/PrivateImage/Png/noFilter'}]});
  }),/No public thumbnail/);
  assert.equal(calls,2);
});
test('pet timestamps remain UTC instants for Discord to render in each viewers local timezone',()=>{
  const d=pet({observedAt:'2026-11-09T03:46:00Z'});
  assert.equal(petPayload(d).embeds[0].timestamp,d.observedAt);
});
test('failed artwork does not prevent a clean text announcement; cached artwork avoids repeat downloads',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'geode-images-'));try {
    const store=new Store(':memory:');store.rememberPet({id:'MiniJewel',portrait:{assetId:'123'}});
    const failed=new PetImages(dir,'https://example.com',{bundledDirectory:join(dir,'missing'),fetchImpl:async()=>new Response(null,{status:403})});assert.equal(await failed.forPet(pet(),store),undefined);
    const bytes=await sharp({create:{width:32,height:32,channels:4,background:'#ffaa00'}}).png().toBuffer();let count=0;
    const cache=new PetImages(dir,'https://example.com',{bundledDirectory:join(dir,'missing'),fetchImpl:async()=>{count++;return new Response(bytes);}});
    const url=await cache.forPet(pet(),store);assert.match(url,/\/pet-images\/[a-f0-9]{64}\.png$/);assert.equal(await cache.forPet(pet(),store),url);assert.equal(count,1);
  }finally{rmSync(dir,{recursive:true,force:true});}
});
test('real bundled boss artwork is served without Roblox downloads or missing portrait metadata',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'geode-bundled-'));try {
    const store=new Store(':memory:');
    const images=new PetImages(dir,'https://example.com',{fetchImpl:async()=>{throw Error('Roblox should not be contacted');}});
    for(const id of ['MiniWarden','MiniScarab','MiniSovereign','MiniAnvil','MiniTriarch','MiniWyrm','MiniMiner','MiniFurnace','MiniSeraph','MiniSun','MiniJewel']) {
      const url=await images.forPet(pet({fields:{Pet:id}}),store);assert.equal(url,`https://example.com/boss-pets/${id}.png`);
      let body,headers;
      assert.equal(images.serve(new URL(url).pathname,{writeHead:(_status,value)=>{headers=value;},end:value=>{body=value;}}),true);
      assert.equal(headers['Content-Type'],'image/png');const metadata=await sharp(body).metadata();assert.equal(metadata.width,128);assert.equal(metadata.height,128);
    }
    assert.equal(images.serve('/boss-pets/../../config.json',{}),false);
  }finally{rmSync(dir,{recursive:true,force:true});}
});
