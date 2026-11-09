export function portraitSpec(value) {
  if(!value || !/^\d{1,20}$/.test(String(value.assetId??'')))return null;
  const spec={assetId:String(value.assetId)};
  const fields=['x','y','width','height'];
  if(fields.some(k=>value[k]!==undefined)) {
    if(fields.some(k=>!Number.isSafeInteger(value[k])) || value.x<0 || value.y<0 || value.width<1 || value.height<1 || fields.some(k=>value[k]>8192))return null;
    for(const k of fields)spec[k]=value[k];
  }
  if(Number.isSafeInteger(value.sheetWidth) && Number.isSafeInteger(value.sheetHeight) && value.sheetWidth>0 && value.sheetHeight>0 && value.sheetWidth<=8192 && value.sheetHeight<=8192) {
    spec.sheetWidth=value.sheetWidth;spec.sheetHeight=value.sheetHeight;
  }
  return spec;
}
export function petMetadata(value) {
  if(!value || !/^[A-Za-z0-9_-]{1,80}$/.test(value.id??''))return null;
  const name=typeof value.name==='string' && value.name.trim() && value.name.length<=100 && !/[\x00-\x1f]/.test(value.name)?value.name:null;
  const portrait=portraitSpec(value.portrait);
  return {id:value.id,...(name?{name}:{}),...(portrait?{portrait}:{})};
}
export const defaultPetNames={MiniJewel:'Living Gemlet'};
export function petId(d) {const p=d.fields?.Pet;return typeof p==='string'?p:p?.Id??p?.id??p?.Name??p?.name;}
export function displayPetName(id,metadata) {
  return metadata?.name??defaultPetNames[id]??String(id??'Unknown pet').replace(/([a-z\d])([A-Z])/g,'$1 $2').replace(/_/g,' ');
}
export function visibleCategory(category,settings) {return category!=='secret' || settings.showSecrets===true;}
