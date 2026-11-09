import { Client, GatewayIntentBits, SlashCommandBuilder, MessageFlags, PermissionFlagsBits, ChannelType } from 'discord.js';
import { petPayload, boardPayload, clean } from './core.mjs';
import { beginCommand, guildAllowed } from './commands.mjs';
import { visibleCategory, petId } from './pets.mjs';
export async function startBot(store,{images}={}) {
  const token=process.env.DISCORD_BOT_TOKEN;
  if(!token) throw Error('Configure the separate Geode bot token');
  const saved=store.db.prepare('SELECT value FROM meta WHERE key=?').get('discord-config');
  let config=saved?JSON.parse(saved.value):{guild:process.env.DISCORD_GUILD_ID,channels:{boss:process.env.GEODE_BOSS_CHANNEL_ID,secret:process.env.GEODE_SECRET_CHANNEL_ID,board:process.env.GEODE_LEADERBOARD_CHANNEL_ID}};
  const targetName=process.env.DISCORD_TARGET_GUILD_NAME??'jhit inc';
  const allowed=g=>guildAllowed(g,config,targetName);
  let settings=store.settings();
  if(!settings.showSecrets)store.suppressSecrets();
  const message=async d=>petPayload(d,{metadata:store.petInfo(petId(d)),thumbnail:await images?.forPet(d,store)});
  const client=new Client({intents:[GatewayIntentBits.Guilds],allowedMentions:{parse:[]}});
  const commands=[new SlashCommandBuilder().setName('geode-leaderboards').setDescription('List observed Geode leaderboards'),
    new SlashCommandBuilder().setName('geode-leaderboard').setDescription('Show an observed leaderboard').addStringOption(o=>o.setName('board').setDescription('Board ID from /geode-leaderboards').setRequired(true)).addIntegerOption(o=>o.setName('page').setDescription('Page number').setMinValue(1)),
    new SlashCommandBuilder().setName('geode-hatches').setDescription('Recent observed rare pets').addStringOption(o=>o.setName('category').setDescription('Pet type').setRequired(true).addChoices({name:'Boss pets',value:'boss'},{name:'Secret pets',value:'secret'})),
    new SlashCommandBuilder().setName('geode-petstats').setDescription('Counts of pet announcements observed by this tracker'),
    new SlashCommandBuilder().setName('geode-settings').setDescription('Show or change pet announcement settings').setDefaultMemberPermissions(PermissionFlagsBits.ManageGuild)
      .addBooleanOption(o=>o.setName('show-secrets').setDescription('Show secret announcements and secret history')),
    new SlashCommandBuilder().setName('geode-setup').setDescription('Choose Geode tracker announcement channels').setDefaultMemberPermissions(PermissionFlagsBits.ManageGuild)
      .addChannelOption(o=>o.setName('boss').setDescription('Boss pet announcements').addChannelTypes(ChannelType.GuildText).setRequired(true))
      .addChannelOption(o=>o.setName('secrets').setDescription('Secret pet announcements').addChannelTypes(ChannelType.GuildText).setRequired(true))
      .addChannelOption(o=>o.setName('leaderboards').setDescription('Leaderboard updates').addChannelTypes(ChannelType.GuildText).setRequired(true))];
  client.on('interactionCreate',async i=>{
    try {
      if(!await beginCommand(i,config))return;
      const guild=i.guild??await client.guilds.fetch(i.guildId);
      console.log(`Command ${i.commandName} received; server=${i.guildId}`);
      if(!allowed(guild)) {
        console.warn(`Server check rejected command; expected=${JSON.stringify(targetName)}; actual=${JSON.stringify(guild.name)}; server=${i.guildId}`);
        return await i.editReply({content:`This tracker is waiting for setup in ${clean(targetName)}. This server is named ${clean(guild.name)}. Ask the bot owner to check the configured server ID.`});
      }
      if(i.commandName==='geode-settings') {
        if(!i.memberPermissions?.has(PermissionFlagsBits.ManageGuild))return await i.editReply({content:'Manage Server permission is required.'});
        const enabled=i.options.getBoolean('show-secrets');
        if(enabled!==null)settings=store.setSettings({showSecrets:enabled});
        await i.editReply({content:`Secret pets: **${settings.showSecrets?'shown':'hidden'}**. Boss announcements stay visible. Changes apply to new announcements; hidden events are not posted later.`});
      } else if(i.commandName==='geode-setup') {
        if(!i.memberPermissions?.has(PermissionFlagsBits.ManageGuild))return await i.editReply({content:'Manage Server permission is required.'});
        const me=guild.members.me??await guild.members.fetchMe();
        const selected={boss:i.options.getChannel('boss',true),secret:i.options.getChannel('secrets',true),board:i.options.getChannel('leaderboards',true)};
        for(const channel of Object.values(selected)) {
          const permissions=channel.permissionsFor(me);
          if(channel.guildId!==i.guildId || !permissions?.has([PermissionFlagsBits.ViewChannel,PermissionFlagsBits.SendMessages,PermissionFlagsBits.EmbedLinks,PermissionFlagsBits.ReadMessageHistory]))return await i.editReply({content:'Grant this bot View Channel, Send Messages, Embed Links and Read Message History in each selected channel.'});
        }
        config={guild:i.guildId,channels:Object.fromEntries(Object.entries(selected).map(([k,v])=>[k,v.id]))};
        store.db.prepare('INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value').run('discord-config',JSON.stringify(config));
        boardVersion.clear();await i.editReply({content:'Geode channels saved. Tracking is ready for collector uploads.'});
      } else if(i.commandName==='geode-leaderboards') {
        const boards=store.boards();await i.editReply({content:boards.length?boards.map(r=>{const d=JSON.parse(r.body);return `${clean(d.title)} (${d.scope}) — \`${clean(r.id)}\``;}).join('\n').slice(0,1900):'No boards captured yet. Run the collector in-game.'});
      } else if(i.commandName==='geode-leaderboard') {
        const row=store.boards().find(r=>r.id===i.options.getString('board'));
        await i.editReply(row?boardPayload(JSON.parse(row.body),(i.options.getInteger('page')??1)-1):{content:'Board not found. Use /geode-leaderboards.'});
      } else if(i.commandName==='geode-hatches') {
        const category=i.options.getString('category');
        if(!visibleCategory(category,settings))return await i.editReply({content:'Secret pets are hidden. A server manager can change this with /geode-settings.'});
        const rows=store.recent(category,3);
        await i.editReply(rows.length?{embeds:await Promise.all(rows.map(async d=>(await message(d)).embeds[0]))}:{content:'No announcements observed yet.'});
      } else if(i.commandName==='geode-petstats')await i.editReply({content:store.stats().filter(r=>visibleCategory(r.category,settings)).map(r=>`${r.category}: ${r.count} observations`).join('\n')||'No announcements observed yet.'});
      else await i.editReply({content:'This command is outdated. Reopen the slash-command menu and choose a current Geode command.'});
      console.log(`Command ${i.commandName} completed; server=${i.guildId}`);
    } catch(error) {
      console.error(`Geode command failed; command=${i.commandName}; server=${i.guildId??'DM'}; code=${error?.code??'unknown'}; type=${error?.name??'Error'}`);
      const response={content:'The command could not finish. Please try again; the bot owner can check the diagnostic logs.'};
      if(i.deferred || i.replied)await i.editReply(response).catch(()=>{});
      else if(i.isRepliable?.())await i.reply({...response,flags:MessageFlags.Ephemeral}).catch(()=>{});
    }
  });
  let working=false,stopped=false,timer;
  const boardVersion=new Map();
  store.cancelPendingBoardPosts();
  function deliveryError(stage,error) {
    const fields=Object.keys(error?.rawError?.errors??{}).join(',');
    const detail=String(error?.message??'').replace(/[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]{20,}/g,'[redacted]').slice(0,240);
    console.error(`Discord delivery delayed; stage=${stage}; code=${error?.code??'unknown'}; fields=${fields}; detail=${detail}`);
  }
  async function tick() {
    if(working || stopped || !client.isReady() || !config.guild || !Object.values(config.channels).every(Boolean))return;working=true;
    try {
      for(const r of store.pending()) {
        try {
        const d=JSON.parse(r.body);
        if(!visibleCategory(d.category,settings)){store.suppressSecrets();continue;}
        const payload=await message(d);
        if(!visibleCategory(d.category,settings)){store.suppressSecrets();continue;}
        const channel=await client.channels.fetch(config.channels[d.category]);
        await channel.send({...payload,nonce:r.id.slice(0,24),enforceNonce:true});store.sent(r.id);
        }catch(error){deliveryError('pet',error);}
      }
      // Startup/re-execution and routine polling both edit the existing leaderboard messages.
      const refreshRevision=store.boardRefreshRevision();
      for(const r of store.boards()) {
        try {
        const version=r.at+':'+refreshRevision;
        const d=JSON.parse(r.body);if(d.scope!=='global'||boardVersion.get(r.id)===version)continue;
        const channel=await client.channels.fetch(config.channels.board);
        let message;
        if(r.message) {
          try {message=await channel.messages.fetch(r.message);} catch(e){if(e.code!==10008)throw e;}
        }
        if(message)await message.edit(boardPayload(d));
        else {message=await channel.send(boardPayload(d));store.db.prepare('UPDATE boards SET message=? WHERE id=?').run(message.id,r.id);}
        boardVersion.set(r.id,version);
        }catch(error){deliveryError('leaderboard-update',error);}
      }
    } catch(error) {deliveryError('queue',error);}
    finally{working=false;}
  }
  async function register(guild) {
    if(allowed(guild))await guild.commands.set(commands.map(c=>c.toJSON()));
  }
  client.on('guildCreate',g=>void register(g).catch(()=>console.error('Guild command registration failed')));
  client.once('clientReady',async()=>{
    try {
      await client.application.commands.set(commands.map(c=>c.toJSON()));
      for(const guild of client.guilds.cache.values())await register(guild);
      console.log('Connected servers: '+JSON.stringify([...client.guilds.cache.values()].map(g=>({id:g.id,name:g.name,allowed:allowed(g)}))));
      console.log(`Geode bot connected as ${client.user.id}; servers=${client.guilds.cache.size}; ${config.guild?'configured':'awaiting invite and /geode-setup'}`);
      timer=setInterval(()=>void tick(),10000);void tick();
    } catch {console.error('Command registration failed');client.destroy();process.exit(1);}
  });
  const destroy=client.destroy.bind(client);client.destroy=()=>{stopped=true;clearInterval(timer);return destroy();};
  await client.login(token);return client;
}
