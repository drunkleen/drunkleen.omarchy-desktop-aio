const {test}=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');const vm=require('node:vm');const path=require('node:path');
function lib(name){const ctx=vm.createContext(name==='SettingsModel.js'?{Ambient:lib('AmbientModel.js')}:{ });vm.runInContext(fs.readFileSync(path.join(__dirname,'..',name),'utf8').replace(/^\.pragma library\s*/,'').replace(/^\.import .*$/gm,''),ctx);return ctx;}
const toml=lib('Toml.js'),model=lib('SettingsModel.js'),weather=lib('WeatherModel.js');
function plain(v){return JSON.parse(JSON.stringify(v));}
test('TOML handles strings, escapes, nested sections, inline tables, arrays and comments',()=>{
 const text='# title\nname = "a # b\\n\\\"quoted\\\"" # comment\nvalues = [1, 2.5, true, "x,y", [3,4]]\n[layout.weather]\nx = 44\n[other]\nrecord = { name = "Hello", enabled = true }\n';const d=toml.parse(text);assert.equal(d.name,'a # b\n"quoted"');assert.deepEqual(plain(d.values),[1,2.5,true,'x,y',[3,4]]);assert.equal(d.layout.weather.x,44);assert.equal(d.other.record.enabled,true);
 assert.deepEqual(plain(toml.parse(toml.patch('',toml.flatten(d)))),plain(d));
});
test('patch preserves comments, unknown settings, sections, and resets without duplicate keys',()=>{
 const input='# keep\nopacity = 0.8 # favorite\n[weather]\ncity = "Dresden"\n[custom]\ntoken = "#literal"\n';const out=toml.patch(input,{opacity:0.6,'weather.units':'imperial'});assert.match(out,/# keep/);assert.match(out,/# favorite/);assert.equal(toml.parse(out).custom.token,'#literal');assert.equal(toml.parse(out).weather.units,'imperial');const reset=toml.patch(out,{opacity:undefined});assert.equal(toml.parse(reset).opacity,undefined);assert.equal(toml.parse(reset).custom.token,'#literal');
});
test('invalid files and unsafe keys fail closed',()=>{for(const s of ['a=1\na=2','opacity = nope','name = "unfinished','[bad','__proto__.x = 2'])assert.throws(()=>toml.parse(s));assert.throws(()=>model.validate('opacity',2));assert.throws(()=>model.validate('weather.units','kelvin'));assert.throws(()=>model.validate('layout.order',['weather']));});
test('multiline values and escaped hashes round trip',()=>{const d=toml.parse('a = [\n 1, #one\n "#two",\n]\nb = """hello\nworld"""\nc = \'literal \\" quotes\'\n');assert.deepEqual(plain(d.a),[1,'#two']);assert.equal(d.b,'hello\nworld');assert.equal(toml.value(toml.encode('\t\\path\n"')), '\t\\path\n"');});
test('old placement migration, explicit anchors and monitor isolation',()=>{const s=model.state({version:1,locked:true,monitors:{DP:{x:.5,y:.7},HDMI:{x:.1,y:.2}},sizes:{DP:.75}});const moved=model.selectAnchor(s,'DP','top-left');assert.equal(moved.monitors.DP,undefined);assert.equal(moved.monitors.HDMI.x,.1);assert.equal(moved.sizes.DP,.75);assert.deepEqual(plain(model.placement('DP',moved,'center',0,0,1000,600,56,56)),{x:56,y:56});assert.equal(s.monitors.DP.x,.5);});
test('component stacking changes order and preserves free positions',()=>{const l={clock:{x:200,y:80}};assert.equal(model.rect('clock',l).x,200);assert.equal(model.rect('weather',l).x,44);const order=model.reorder(model.components,'weather','clock');assert.equal(order[1],'weather');assert.equal(model.rect('clock',l).x,200);assert.deepEqual(plain(model.bounded('clock',10000,-20,true)),{x:391.28,y:0});});
test('city validation rejects bad results and distinguishes namesakes',()=>{const cities=weather.locations(JSON.stringify({results:[{name:'Paris',admin1:'Texas',country:'USA',latitude:33,longitude:-95},{name:'Paris',admin1:'Île-de-France',country:'France',latitude:48,longitude:2},{name:'bad',latitude:1000,longitude:0}]}));assert.equal(cities.length,2);assert.notEqual(cities[0].label,cities[1].label);assert.throws(()=>weather.forecast('{}'));});
test('request generation prevents stale results and results after disabling',()=>{assert.equal(weather.current(1,2,true),false);assert.equal(weather.current(2,2,false),false);assert.equal(weather.current(2,2,true),true);});
function configAPI(initial){
 let text=initial;
 const source=fs.readFileSync(path.join(__dirname,'..','Config.qml'),'utf8');
 const ctx=vm.createContext({Toml:toml,Model:model,overrides:toml.parse(text),pending:{},baseline:{},ready:true,invalid:false,writing:false,exists:true,error:'',diskText:text,debounce:{restart(){}},data:{},file:{reload(){ctx.accept(text);},text(){return text;},setText(next){text=next;ctx.pending={};ctx.baseline={};ctx.writing=false;ctx.accept(text);},waitForJob(){}}});
 ctx.root=ctx;Object.defineProperty(ctx,'dirty',{get(){return Object.keys(ctx.pending).length>0;}});
 vm.runInContext(source.slice(source.indexOf('  function get('),source.indexOf('  property FileView defaultFile:')),ctx);
 return {api:ctx,text:()=>text,external:next=>{text=next;ctx.accept(text);}};
}
test('configuration API debounces patches, preserves concurrent unrelated keys, resets and imports',()=>{
 const c=configAPI('# user\nopacity=.80\n'.replace('.80','0.80')+'[weather]\ncity="Dresden"\n[unrelated]\nvalue=1\n');
 assert.equal(c.api.setValue('opacity',.7),true);c.external(c.text().replace('value=1','value=2'));c.api.flush();assert.equal(c.api.error,'');assert.equal(toml.parse(c.text()).opacity,.7);assert.equal(toml.parse(c.text()).unrelated.value,2);
 c.api.resetValue('opacity');c.api.flush();assert.equal(toml.parse(c.text()).opacity,undefined);
 c.api.importText('clock24h=false');c.api.flush();assert.equal(toml.parse(c.text()).clock24h,false);assert.equal(toml.parse(c.text()).unrelated.value,2);assert.match(c.text(),/# user/);
 c.api.resetSection('weather');c.api.flush();assert.equal(toml.parse(c.text()).weather,undefined);
});
test('same-key concurrent edits and malformed external files are never silently overwritten',()=>{
 const c=configAPI('opacity=0.8\n');c.api.setValue('opacity',.7);c.external('opacity=0.9\n');c.api.flush();assert.match(c.api.error,/conflict/);assert.equal(toml.parse(c.text()).opacity,.9);assert.equal(c.api.pending.opacity,.7);
 const d=configAPI('opacity=0.8');d.api.setValue('opacity',.7);d.external('opacity=broken');d.api.flush();assert.equal(d.text(),'opacity=broken');assert.equal(d.api.invalid,true);assert.equal(d.api.setValue('clock24h',false),false);
});
test('changing city through the API clears saved coordinates; choosing a validated city preserves them',()=>{
 const c=configAPI('[weather]\ncity="Paris"\nlatitude=48\nlongitude=2\n');c.api.setSectionValue('weather','city','Dresden');c.api.flush();assert.equal(toml.parse(c.text()).weather.latitude,undefined);
 c.api.setValues({'weather.city':'Paris','weather.latitude':33,'weather.longitude':-95});c.api.flush();assert.equal(toml.parse(c.text()).weather.latitude,33);
});
test('patch writes standard TOML tables and updates nested inline values safely',()=>{
 const out=toml.patch('[weather]\ncity="Dresden"\n[layout]\norder=["weather"]\n',{'weather.units':'imperial','layout.clock.x':40});
 assert.ok(out.indexOf('"units"')>out.indexOf('[weather]'));assert.ok(out.indexOf('"clock"."x"')>out.indexOf('[layout]'));
 const inline=toml.patch('weather={city="Paris", units="metric"} #keep\n',{'weather.units':'imperial','weather.latitude':48});assert.equal(toml.parse(inline).weather.units,'imperial');assert.equal(toml.parse(inline).weather.latitude,48);assert.match(inline,/#keep/);
 assert.throws(()=>toml.parse('[weather]\ncity="X"\n[weather]\nunits="metric"'));
});
test('drag and resize preserve aspect ratio, pointer offset and screen boundaries',()=>{
 assert.deepEqual(plain(model.dragPoint({x:100,y:200},{x:110,y:220},{x:140,y:250},1000,600)),{x:130,y:230});
 assert.deepEqual(plain(model.dragPoint({x:100,y:200},{x:110,y:220},{x:-100,y:900},1000,600)),{x:0,y:600});
 assert.ok(Math.abs(model.resizeScale(.5,70.8,45.4,1920,1080,100,100)-.6)<1e-10);
 assert.equal(model.resizeScale(.5,99999,99999,800,600,100,100),700/708);
 assert.equal(model.resizeScale(.5,-99999,-99999,800,600,100,100),.1);
});
test('quoted unknown keys retain literal dots during export and unrelated updates',()=>{
 const source='"user.name"="literal"\n[user]\nname="nested"\n';
 const d=toml.parse(source);assert.equal(d['user.name'],'literal');assert.equal(d.user.name,'nested');
 const exported=toml.patch('',toml.flatten(d));assert.deepEqual(plain(toml.parse(exported)),plain(d));
 const patched=toml.patch(source,{opacity:.7});assert.equal(toml.parse(patched)['user.name'],'literal');
 assert.throws(()=>toml.parse('custom={__tomlRaw="malformed"}'));
});
