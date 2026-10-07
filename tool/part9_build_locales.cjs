const fs=require('fs'),path=require('path');
fs.mkdirSync('assets/l10n',{recursive:true});
const maps={en:{},si:{},ta:{}};
for(const source of ['tool/part9_translations.tsv','tool/part92_translations.tsv'])
for(const line of fs.readFileSync(source,'utf8').replace(/^\uFEFF/,'').split(/\r?\n/)){if(!line.trim())continue;const [en,si,ta]=line.split('|');if(!en||!si||!ta)throw Error(line); if(maps.en[en])throw Error('Duplicate '+en);maps.en[en]=en;maps.si[en]=si;maps.ta[en]=ta;}
for(const [code,map] of Object.entries(maps))fs.writeFileSync(`assets/l10n/${code}.json`,JSON.stringify(map,null,2)+'\n');
console.log(Object.keys(maps.en).length+' resources per locale');
const codes=['en','si','ta'];const values=Object.fromEntries(codes.map(c=>[c,JSON.parse(fs.readFileSync(`assets/l10n/${c}.json`,'utf8'))]));fs.writeFileSync('lib/core/localization/messages.g.dart','// Generated from assets/l10n/*.json by tool/part9_build_locales.cjs.\nconst localizedMessages = <String, Map<String, String>>'+JSON.stringify(values,null,2).replace(/\$/g,'\\$')+';\n');

