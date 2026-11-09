import { MessageFlags } from 'discord.js';
import { combinedLeaderboardCommands } from './leaderboards.mjs';

export const normalizeGuildName = name => String(name??'').normalize('NFKC').toLowerCase().replace(/[^a-z0-9]/g,'');

export function guildAllowed(guild, config, targetName) {
  return !!guild && (config.guild ? guild.id===config.guild : normalizeGuildName(guild.name)===normalizeGuildName(targetName));
}

// Every recognized command is acknowledged before any cache, access or storage work.
export async function beginCommand(interaction, config) {
  if(!interaction.isChatInputCommand() || (!interaction.commandName.startsWith('geode-') && !combinedLeaderboardCommands.has(interaction.commandName)))return false;
  await interaction.deferReply(combinedLeaderboardCommands.has(interaction.commandName)?{}:{flags:MessageFlags.Ephemeral});
  if(!interaction.guildId) {
    await interaction.editReply({content:'Run this command inside your Discord server, rather than in a direct message.'});
    return false;
  }
  if(config.guild && interaction.guildId!==config.guild) {
    await interaction.editReply({content:'This tracker is configured for a different server.'});
    return false;
  }
  return true;
}
