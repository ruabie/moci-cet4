'use strict';

// Verify that the published page references the same versioned assets as this
// checkout. New app.js/styles.css cache-busters must not require CI code edits.
const fs = require('node:fs');

const BASE = 'https://ruabie.github.io/moci-cet4/kotoba/';
const FILES = [
  'book-data.js','vocab-13.js','vocab-14.js','vocab-15.js',
  'vocab-16.js','extra-words.js','app.js','styles.css'
];
const LOCAL = fs.readFileSync('kotoba/index.html', 'utf8');

function refs(html) {
  return html.split('"./').slice(1).map(part => part.split('"')[0]);
}
function namedRef(list, file) {
  return list.find(ref => ref.split('?')[0] === file);
}
const expected = Object.fromEntries(FILES.map(file => [file, namedRef(refs(LOCAL), file)]));
for (const [file, value] of Object.entries(expected)) {
  if (!value || !value.startsWith(file + '?v=')) throw new Error('Local HTML missing versioned asset ' + file);
}

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
async function request(url) {
  const response = await fetch(url, {
    redirect: 'follow',
    signal: AbortSignal.timeout(12000),
    headers: { 'Cache-Control': 'no-cache' }
  });
  if (!response.ok) throw new Error(url + ' HTTP ' + response.status);
  return response.text();
}

async function verify() {
  const html = await request(BASE + '?cache_check=' + Date.now());
  if (!html.includes('id="cardPos"')) throw new Error('Published page missing study POS element');
  const published = refs(html);
  for (const [file, requiredRef] of Object.entries(expected)) {
    const publishedRef = namedRef(published, file);
    if (publishedRef !== requiredRef) {
      throw new Error('Published ' + file + ' is ' + (publishedRef || 'missing') + ', expected ' + requiredRef);
    }
  }
  for (const [file, ref] of Object.entries(expected)) {
    const body = await request(new URL('./' + ref, BASE));
    if (!body.trim()) throw new Error(file + ' returned empty content');
    if (file === 'app.js' && !body.includes('SUPPLEMENT_WORDS')) throw new Error('App missing SUPPLEMENT_WORDS');
    if (file === 'vocab-16.js' && !body.includes('KOTOBA_SUPPLEMENTS')) throw new Error('V16 missing supplements');
  }
  await request(new URL('./sw.js', BASE));
}

(async () => {
  let last;
  for (let attempt = 1; attempt <= 30; attempt++) {
    try {
      await verify();
      console.log('KOTOBA LIVE SITE VERIFIED: current HTML and versioned JS/CSS all accessible');
      return;
    } catch (error) {
      last = error;
      console.log('Attempt ' + attempt + '/30: ' + error.message);
      if (attempt < 30) await sleep(6000);
    }
  }
  console.error('Published site did not converge: ' + last.message);
  process.exitCode = 1;
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
