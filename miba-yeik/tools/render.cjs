const {chromium}=require('playwright');const fs=require('fs');const dir=process.argv[2];const N=+process.argv[3]||1;
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:1280,height:720}});
await p.goto('file://'+dir+'/scene.html');
for(let i=0;i<N;i++){const d=await p.evaluate(i=>{draw(i/60);return document.getElementById('c').toDataURL('image/png')},i);
fs.writeFileSync(`${dir}/frames/f${String(i).padStart(4,'0')}.png`,Buffer.from(d.split(',')[1],'base64'))}
await b.close()})()
