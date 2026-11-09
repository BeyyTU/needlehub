import { boardPayload } from './core.mjs';
export const combinedLeaderboardCommands=new Set(['leaderboards','geode-leaderboards']);
const nativeBoards=[['TopMiners','Top Miners'],['DeepestEndless','Deepest Endless'],['FastestHard','Fastest Hard'],['FastestEscapes','Fastest Escapes'],['TopWins','Top Wins']];

export function allLeaderboardsPayload(records) {
  const boards=records.map(r=>typeof r.body==='string'?JSON.parse(r.body):r).filter(d=>d.scope==='global');
  if(!boards.length)return {content:'No global leaderboards captured yet. Open the Geode lobby with the hub running.',allowedMentions:{parse:[]}};
  const byId=new Map(boards.map(d=>[d.boardId,d]));
  const embeds=nativeBoards.map(([id,title])=>{
    const d=byId.get(id);
    if(!d)return {title,description:'Waiting for the next lobby capture.',color:0x48B89A};
    const embed=boardPayload(d).embeds[0];
    const lines=embed.description.split('\n');const shown=[];let length=0;
    for(const line of lines.slice(0,10)) {
      if(length+line.length+1>900)break;
      shown.push(line);length+=line.length+1;
    }
    embed.description=shown.join('\n');
    delete embed.footer;
    return embed;
  });
  return {allowedMentions:{parse:[]},embeds};
}
