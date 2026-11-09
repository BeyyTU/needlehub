import { WebhookClient } from 'discord.js';
import { boardPayload, petPayload } from './core.mjs';
import { petId, visibleCategory } from './pets.mjs';
import { createDeliveryScheduler } from './delivery.mjs';

export function webhookIdentity(value) {
  try {
    const url=new URL(value);
    const match=/^\/api\/(?:v\d+\/)?webhooks\/(\d+)\/([A-Za-z0-9._-]+)\/?$/.exec(url.pathname);
    if(url.protocol!=='https:' || !['discord.com','discordapp.com'].includes(url.hostname) || url.port || url.username || url.password || url.hash || !match)throw Error();
    if([...url.searchParams.keys()].some(k=>k!=='thread_id') || (url.searchParams.has('thread_id')&&!/^\d+$/.test(url.searchParams.get('thread_id'))))throw Error();
    return {id:match[1],threadId:url.searchParams.get('thread_id')??undefined};
  }catch {throw Error('Use a valid Discord incoming-webhook URL');}
}
export function webhookRoutes(store,env) {
  const saved=store.webhookConfig();const common=env.GEODE_WEBHOOK_URL;
  const urls={boss:env.GEODE_BOSS_WEBHOOK_URL??common??saved.urls?.boss,secret:env.GEODE_SECRET_WEBHOOK_URL??common??saved.urls?.secret,board:env.GEODE_LEADERBOARD_WEBHOOK_URL??common??saved.urls?.board};
  const hasEnv=Object.values({common,boss:env.GEODE_BOSS_WEBHOOK_URL,secret:env.GEODE_SECRET_WEBHOOK_URL,board:env.GEODE_LEADERBOARD_WEBHOOK_URL}).some(Boolean);
  const configured=store.db.prepare('SELECT 1 FROM meta WHERE key=?').get('webhook-config');
  return {enabled:configured?saved.enabled===true:hasEnv,urls};
}
export function startWebhookRelay(store,{images,env=process.env,clientFactory=url=>new WebhookClient({url}),scheduler=true,report=(stage,error)=>console.error(`Webhook delivery delayed; stage=${stage}; code=${error?.code??'unknown'}`)}={}) {
  const clients=new Map(),versions=new Map();let delivery,stopped=false;
  const initial=webhookRoutes(store,env);if(initial.enabled)for(const url of Object.values(initial.urls))if(url)webhookIdentity(url);
  function route(category) {
    const config=webhookRoutes(store,env);const url=config.enabled?config.urls[category]:null;
    if(!url)return null;
    const identity=webhookIdentity(url);if(!clients.has(url))clients.set(url,clientFactory(url));
    return {client:clients.get(url),url,...identity};
  }
  function owns(category) {const config=webhookRoutes(store,env);return config.enabled && !!config.urls[category];}
  async function flush() {
    if(stopped)return;let sent=0;
    for(const row of store.pending()) {
      let claimed=false;
      try {
        const d=JSON.parse(row.body);if(!owns(d.category))continue;
        if(!visibleCategory(d.category,store.settings())){store.suppressSecrets();continue;}
        claimed=store.claimPet(row.id);if(!claimed)continue;
        const target=route(d.category);
        const payload=petPayload(d,{metadata:store.petInfo(petId(d)),thumbnail:await images?.forPet(d,store)});
        const current=webhookRoutes(store,env);
        if(stopped || !current.enabled || current.urls[d.category]!==target.url || !visibleCategory(d.category,store.settings()))continue;
        const message=await target.client.send({...payload,username:'Geode Tracker',...(target.threadId?{threadId:target.threadId}:{})});
        if(!message?.id)throw Error('Webhook did not confirm delivery');
        store.sent(row.id);sent++;
      }catch(error){report('pet',error);}finally{if(claimed)store.releasePet(row.id);}
    }
    if(owns('board')) {
      for(const row of store.boards()) {
        try {
          const d=JSON.parse(row.body);if(d.scope!=='global')continue;
          const target=route('board');const key=target.id+':'+(target.threadId??'')+':'+row.id;
          const revision=row.at+':'+store.boardRefreshRevision();if(versions.get(key)===revision)continue;
          const identity=target.id+':'+(target.threadId??'');
          const existing=store.webhookMessage(row.id,identity);let message;
          if(existing) {
            try{message=await target.client.editMessage(existing,{...boardPayload(d),...(target.threadId?{threadId:target.threadId}:{})});}
            catch(error){if(error.code!==10008)throw error;}
          }
          if(!message){message=await target.client.send({...boardPayload(d),username:'Geode Tracker',...(target.threadId?{threadId:target.threadId}:{})});if(!message?.id)throw Error('Webhook did not confirm board');store.setWebhookMessage(row.id,identity,message.id);}
          versions.set(key,revision);
        }catch(error){report('leaderboard',error);}
      }
    }
    if(sent && store.pending().some(row=>owns(JSON.parse(row.body).category)))delivery?.request();
  }
  if(scheduler){delivery=createDeliveryScheduler(flush,{onError:error=>report('scheduler',error)});delivery.request();}
  return {owns,flush,requestDelivery(){delivery?.request();},configurationChanged(){versions.clear();delivery?.request();},isEnabled(){return webhookRoutes(store,env).enabled;},stop(){stopped=true;delivery?.stop();for(const client of clients.values())client.destroy?.();}};
}
