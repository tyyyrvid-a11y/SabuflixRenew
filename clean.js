const fs = require('fs'); 
let txt = fs.readFileSync('www/js/app.js', 'utf8'); 
txt = txt.replace(/if \(window\.lucide\) lucide\.createIcons\(\);/g, ''); 
txt = txt.replace(/<i data-lucide="check"><\/i>/g, 'Salvo'); 
txt = txt.replace(/<i data-lucide="plus"><\/i>/g, '+'); 
txt = txt.replace(/<i data-lucide="chevron-right".*?><\/i>/g, '>'); 
txt = txt.replace(/<i data-lucide="download".*?><\/i>/g, 'Baixar'); 
txt = txt.replace(/<i data-lucide="bookmark"><\/i>/g, '+'); 
fs.writeFileSync('www/js/app.js', txt);
