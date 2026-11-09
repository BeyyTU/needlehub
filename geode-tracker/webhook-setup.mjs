import { PermissionFlagsBits } from 'discord.js';
import { webhookIdentity } from './webhooks.mjs';
class WebhookSetupError extends Error {constructor(message){super(message);this.name='WebhookSetupError';}}

export function configuredWebhooks(env=process.env) {
  const common=env.GEODE_WEBHOOK_URL;
  const urls={boss:env.GEODE_BOSS_WEBHOOK_URL??common,secret:env.GEODE_SECRET_WEBHOOK_URL??common,board:env.GEODE_LEADERBOARD_WEBHOOK_URL??common};
  if(!Object.values(urls).some(Boolean))return null;
  if(!Object.values(urls).every(Boolean))throw new WebhookSetupError('Set GEODE_WEBHOOK_URL in Railway for one webhook covering all announcements, or configure all three route variables.');
  try {for(const url of Object.values(urls))webhookIdentity(url);}
  catch {throw new WebhookSetupError('Check the private Discord webhook URL in Railway. It must be a valid Discord incoming-webhook URL.');}
  return {enabled:true,urls};
}

export async function provisionWebhooks({guild,botId,channels}) {
  const resolved=new Map();
  for(const category of ['boss','secret','board']) {
    const id=channels[category];if(!id)throw new WebhookSetupError('Run /geode-setup to choose all three channels first.');
    if(!resolved.has(id))resolved.set(id,await guild.channels.fetch(id));
  }
  const me=guild.members.me??await guild.members.fetchMe();
  const missing=[...resolved.values()].filter(c=>!c || c.guildId!==guild.id || typeof c.createWebhook!=='function' || !c.permissionsFor(me)?.has([PermissionFlagsBits.ViewChannel,PermissionFlagsBits.ManageWebhooks]));
  if(missing.length)throw new WebhookSetupError('Give Geode Tracker View Channel and Manage Webhooks in the configured tracking channels, then run this command again.');
  const hooks=new Map();
  for(const [id,channel] of resolved) {
    const existing=await channel.fetchWebhooks();
    let hook=existing.find(h=>h.name==='Geode Tracker' && (h.owner?.id===botId || h.applicationId===botId));
    if(!hook)hook=await channel.createWebhook({name:'Geode Tracker',reason:'Geode webhook delivery enabled by a server manager'});
    webhookIdentity(hook.url);hooks.set(id,hook.url);
  }
  return {enabled:true,channels:{...channels},urls:Object.fromEntries(Object.entries(channels).filter(([key])=>['boss','secret','board'].includes(key)).map(([key,id])=>[key,hooks.get(id)]))};
}
