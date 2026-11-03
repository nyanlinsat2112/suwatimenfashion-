demo=open('/home/claude/garage-pos/src/garage-pos-demo-v1.html').read()
css=demo[demo.index('<style>')+7:demo.index('</style>')]+open('src/app-extra.css').read()
t=open('src/admin-template.html').read().replace('/*CSS*/',css)
open('admin.html','w').write(t);print('admin.html',len(t))
