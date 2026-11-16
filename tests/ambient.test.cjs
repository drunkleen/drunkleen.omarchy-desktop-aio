const {test}=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');const vm=require('node:vm');const path=require('node:path');
const root=path.resolve(__dirname,'..');
function load(name,context={}){vm.createContext(context);vm.runInContext(fs.readFileSync(path.join(root,name),'utf8').replace(/^\.pragma library\s*/,'').replace(/^\.import .*$/gm,''),context);return context;}
const model=load('AmbientModel.js'),toml=load('Toml.js'),schema=load('SettingsModel.js',{Ambient:model});
const auto={enabled:true,mode:'auto'};
const march=new Date(2026,2,1),winter=new Date(2026,0,15),summer=new Date(2026,6,1);
function result(config,weather={},date=march){return JSON.parse(JSON.stringify(model.resolve(config,weather,date)));}
test('every manual effect overrides both weather and season',()=>{
 for(const mode of ['sakura','green_leaves','yellow_leaves','orange_leaves','rain','snow']){
   assert.deepEqual(result({mode},{available:true,code:75,latitude:-33},winter),{effect:mode,reason:'manual'});
   assert.equal(result({mode},{available:true,code:95},summer).effect,mode);
 }
});
test('Disabled uses the existing enabled flag and never changes the remembered mode',()=>{
 for(const mode of model.modes){const cfg={mode,enabled:false};assert.deepEqual(result(cfg,{available:true,code:75}),{effect:'none',reason:'disabled'});assert.equal(model.normalize(cfg).mode,mode);}
});
test('all required snowfall WMO codes select snow in either hemisphere in every season',()=>{
 for(const code of [71,73,75,77,85,86])for(const latitude of [51,-33])for(const date of [march,winter,summer])assert.equal(result(auto,{available:true,code,latitude},date).effect,'snow',`${code}/${latitude}`);
});
test('all drizzle, rain, showers, freezing precipitation and storm codes select rain',()=>{
 for(const code of [51,53,55,56,57,61,63,65,66,67,80,81,82,95,96,99])for(const latitude of [51,-33])assert.equal(result(auto,{available:true,code,latitude},winter).effect,'rain',`${code}/${latitude}`);
});
test('all northern and southern meteorological months resolve deterministically',()=>{
 const northern=['none','none','sakura','sakura','sakura','green_leaves','green_leaves','green_leaves','orange_leaves','orange_leaves','orange_leaves','none'];
 for(let month=0;month<12;month++){
  assert.equal(result(auto,{latitude:51},new Date(2026,month,15)).effect,northern[month]);
  assert.equal(result(auto,{latitude:-33},new Date(2026,month,15)).effect,northern[(month+6)%12]);
 }
});
test('season boundaries use the configured location date offset where available',()=>{
 for(const [month,expected] of [[2,'sakura'],[5,'green_leaves'],[8,'orange_leaves'],[11,'none']]){
  const before=new Date(2026,month,1,0,0,0);const prior=new Date(before.getTime()-1);
  assert.notEqual(result(auto,{latitude:51},prior).effect,expected);
  assert.equal(result(auto,{latitude:51},before).effect,expected);
 }
 const utc=new Date('2026-02-28T23:30:00Z');assert.equal(result(auto,{latitude:51,utcOffset:3600},utc).effect,'sakura');
 assert.equal(result(auto,{latitude:51,utcOffset:-3600},utc).effect,'none');
});
test('missing weather, irrelevant codes and missing coordinates use seasonal fallback, never winter snow',()=>{
 for(const weather of [{},{available:false,code:75},{available:true,code:0},{available:true,code:45},{available:true,code:999}])assert.equal(result(auto,weather,winter).effect,'none');
 assert.equal(result(auto,{},march).effect,'sakura');assert.equal(result(auto,{latitude:null},march).effect,'sakura');assert.equal(result(auto,{latitude:0},march).effect,'sakura');
 assert.equal(result(auto,{latitude:-33,available:false,code:61},march).effect,'orange_leaves');
});
test('legacy configuration without an ambient section remains Sakura with original tuning',()=>{
 const cfg=model.normalize(undefined),settings=model.settings(undefined,'sakura');assert.equal(cfg.mode,'sakura');assert.equal(cfg.enabled,true);assert.equal(result({}).effect,'sakura');assert.equal(settings.petal_count,25);assert.equal(settings.fall_px,60);assert.equal(settings.wind_strength,.15);assert.equal(settings.opacity,.75);
});
test('invalid modes/numeric settings are rejected before persistence and normalized safely for rendering',()=>{
 assert.throws(()=>schema.validate('ambient.mode','fire'));assert.throws(()=>schema.validate('ambient.enabled',1));assert.throws(()=>schema.validate('ambient.density',2));assert.throws(()=>schema.validate('ambient.speed',NaN));assert.throws(()=>schema.validate('ambient.size',0));assert.throws(()=>schema.validate('ambient.opacity',-.1));
 const cfg=model.normalize({mode:'unknown',density:999,size:NaN,speed:-1});assert.equal(cfg.mode,'sakura');assert.equal(cfg.density,1);assert.equal(cfg.size,1);assert.equal(cfg.speed,.1);
});
test('ambient persistence preserves unknown settings and remembers mode while disabled',()=>{
 const initial='# personal\n[ambient]\nmode="orange_leaves"\ndensity=0.4\n[custom]\nkeep=true\n';const disabled=toml.patch(initial,{'ambient.enabled':false});assert.equal(toml.parse(disabled).ambient.mode,'orange_leaves');assert.equal(toml.parse(disabled).custom.keep,true);const enabled=toml.patch(disabled,{'ambient.enabled':true});assert.equal(result(toml.parse(enabled).ambient).effect,'orange_leaves');assert.match(enabled,/# personal/);
});
test('manual/automatic transitions are stateless; weather always overrides seasonal selection',()=>{
 assert.equal(result({mode:'yellow_leaves'},{available:true,code:75}).effect,'yellow_leaves');assert.equal(result(auto,{available:true,code:75}).effect,'snow');assert.equal(result(auto,{available:false,code:75}).effect,'sakura');assert.equal(result({mode:'rain'},{available:false},winter).effect,'rain');
});
test('one bounded pool supports all modes, density zero, and legacy ownership gating',()=>{
 for(const mode of model.modes.filter(x=>x!=='auto'))for(const density of [0,.4,1]){const s=model.settings({density},mode);assert.ok(s.petal_count>=0&&s.petal_count<=128);assert.equal(s.fps,30);if(density===0)assert.equal(s.petal_count,0);assert.ok(s.palette.petals.length>1);}
 assert.equal(model.ownsSurface(true,true,true),false);assert.equal(model.ownsSurface(true,false,false),false);assert.equal(model.ownsSurface(false,true,false),false);assert.equal(model.ownsSurface(true,true,false),true);
});
