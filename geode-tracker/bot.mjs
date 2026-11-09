import { Client, GatewayIntentBits, SlashCommandBuilder, MessageFlags } from 'discord.js';
import { petPayload, boardPayload, clean } from './core.mjs';
export async function startBot(store) {
  const token=process.env.DISCORD_BOT_TOKEN;
  const guild=process.env.DISCORD_GUILD_ID;
  const channels={boss:process.env.GEODE_BOSS_CHANNEL_ID,secret:process.env.GEODE_SECRET_CHANNEL_ID,board:process.env.GEODE_LEADERBOARD_CHANNEL_ID};
  if(!token || !/^\d+$/.test(guild??'') || Object.values(channels).some(id=>!/^\d+$/.test(id??''))) throw Error('Configure separate bot token, guild ID and three Geode channel IDs');
  const client=new Client({intents:[GatewayIntentBits.Guilds],allowedMentions:{parse:[]}});
  const commands=[new SlashCommandBuilder().setName('geode-leaderboards').setDescription('List observed Geode leaderboards'),
    new SlashCommandBuilder().setName('geode-leaderboard').setDescription('Show an observed leaderboard').addStringOption(o=>o.setName('board').setDescription('Board ID from /geode-leaderboards').setRequired(true)).addIntegerOption(o=>o.setName('page').setDescription('Page number').setMinValue(1)),
    new SlashCommandBuilder().setName('geode-hatches').setDescription('Recent observed rare pets').addStringOption(o=>o.setName('category').setDescription('Pet type').setRequired(true).addChoices({name:'Boss pets',value:'boss'},{name:'Secret pets',value:'secret'})),
    new SlashCommandBuilder().setName('geode-petstats').setDescription('Counts of pet announcements observed by this tracker')];
  client.on('interactionCreate',async i=>{
    if(!i.isChatInputCommand() || i.guildId!==guild) return;
    try {
      await i.deferReply({flags:MessageFlags.Ephemeral});
      if(i.commandName==='geode-leaderboards') {
        const boards=store.boards();await i.editReply({content:boards.length?boards.map(r=>{const d=JSON.parse(r.body);return `${clean(d.title)} (${d.scope}) — \`${clean(r.id)}\``;}).join('\n').slice(0,1900):'No boards captured yet. Run the collector in-game.'});
      } else if(i.commandName==='geode-leaderboard') {
        const row=store.boards().find(r=>r.id===i.options.getString('board'));
        await i.editReply(row?boardPayload(JSON.parse(row.body),(i.options.getInteger('page')??1)-1):{content:'Board not found. Use /geode-leaderboards.'});
      } else if(i.commandName==='geode-hatches') {
        const rows=store.recent(i.options.getString('category'),3);
        await i.editReply(rows.length?{embeds:rows.map(d=>petPayload(d).embeds[0])}:{content:'No announcements observed yet.'});
      } else if(i.commandName==='geode-petstats')await i.editReply({content:store.stats().map(r=>`${r.category}: ${r.count} observations`).join('\n')||'No announcements observed yet.'});
    } catch {console.error('Geode command failed'); if(i.deferred)await i.editReply({content:'Unable to load this capture.'}).catch(()=>{});}
  });
  let working=false,stopped=false,timer;
  const boardVersion=new Map();
  async function tick() {
    if(working || stopped || !client.isReady())return;working=true;
    try {
      for(const r of store.pending()) {
        const d=JSON.parse(r.body);const channel=await client.channels.fetch(channels[d.category]);
        await channel.send({...petPayload(d),nonce:r.id.slice(0,24),enforceNonce:true});store.sent(r.id);
      }
      // Publish global board headers; server-only snapshots remain available through commands.
      for(const r of store.boards()) {
        const d=JSON.parse(r.body);if(d.scope!=='global'||boardVersion.get(r.id)===r.at)continue;
        const channel=await client.channels.fetch(channels.board);
        let message;
        if(r.message) {
          try {message=await channel.messages.fetch(r.message);} catch(e){if(e.code!==10008)throw e;}
        }
        if(message)await message.edit(boardPayload(d));
        else {message=await channel.send(boardPayload(d));store.db.prepare('UPDATE boards SET message=? WHERE id=?').run(message.id,r.id);}
        boardVersion.set(r.id,r.at);
      }
    } catch {console.error('Discord delivery delayed; queued captures retained for retry');}
    finally{working=false;}
  }
  client.once('clientReady',async()=>{
    try {
      const target=await client.guilds.fetch(guild);
      // Dedicated bot: this replaces only this bot's commands in the configured guild.
      await target.commands.set(commands.map(c=>c.toJSON()));
      console.log('Geode bot connected');timer=setInterval(()=>void tick(),10000);void tick();
    } catch {console.error('Command registration failed');client.destroy();process.exit(1);}
  });
  const destroy=client.destroy.bind(client);client.destroy=()=>{stopped=true;clearInterval(timer);return destroy();};
  await client.login(token);return client;
}
