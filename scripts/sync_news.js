const admin = require('firebase-admin');
const Parser = require('rss-parser');
const cloudinary = require('cloudinary').v2;

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY);
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}
const db = admin.firestore();

const parser = new Parser({
  headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'application/rss+xml, application/xml, text/xml; q=0.9, */*; q=0.8',
  },
  timeout: 10000,
  customFields: {
    item: [
      ['media:content', 'mediaContent'],
      ['enclosure', 'enclosure'],
      ['content:encoded', 'contentEncoded'],
      ['category', 'categories', { keepArray: true }],
    ],
  },
});

// Targeted feeds for Biblical Archaeology, Christian/Prophetic Worldview, and Middle East Defense
const RSS_FEEDS = [
  {
    url: 'https://www.biblicalarchaeology.org/feed/',
    category: 'ARCHAEOLOGY & HISTORY',
    source: 'Biblical Archaeology Review',
  },
  {
    url: 'https://israel365news.com/feed/',
    category: 'BIBLICAL PROPHECY',
    source: 'Israel365 News',
  },
  {
    url: 'https://www.jpost.com/rss/rssfeedsisraelnews.aspx',
    category: 'WAR & REGION UPDATES',
    source: 'Jerusalem Post',
  },
  {
    url: 'https://www.jpost.com/rss/rssfeedschristiannews.aspx',
    category: 'CHRISTIAN WORLD & FAITH',
    source: 'JPost Christian World',
  },
  {
    url: 'https://www.timesofisrael.com/feed/',
    category: 'ISRAEL & NATION',
    source: 'Times of Israel',
  },
];

function extractImageUrl(item) {
  if (item.enclosure?.url) return item.enclosure.url;
  if (item.mediaContent?.$?.url) return item.mediaContent.$.url;

  const html = `${item.contentEncoded || ''} ${item.content || ''}`;
  const match = html.match(/<img[^>]+src=["']([^"']+)["']/i);
  return match ? match[1] : null;
}

async function run() {
  try {
    let collectedItems = [];

    // Pull 2 candidate items per feed so we have an abundant buffer of 10 items
    for (const feed of RSS_FEEDS) {
      try {
        console.log(`Querying: ${feed.source}`);
        const feedData = await parser.parseURL(feed.url);
        
        for (const item of feedData.items.slice(0, 2)) {
          collectedItems.push({
            title: (item.title || '').trim(),
            link: item.link || '',
            snippet: (item.contentSnippet || item.summary || '').replace(/<[^>]*>?/gm, '').slice(0, 220).trim(),
            fullContent: (item.contentEncoded || item.content || item.contentSnippet || '').trim(),
            pubDate: item.pubDate ? new Date(item.pubDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : 'Today',
            rawImage: extractImageUrl(item),
            category: feed.category,
            sourceName: feed.source,
          });
        }
      } catch (err) {
        console.warn(`Feed ${feed.source} skipped: ${err.message}`);
      }
    }

    // Deduplicate and ensure distinct categories in the top selection
    const uniqueCategoryMap = new Map();
    const finalSelected = [];

    // First pass: pick 1 article per category to guarantee broad variety
    for (const item of collectedItems) {
      if (!uniqueCategoryMap.has(item.category) && finalSelected.length < 5) {
        uniqueCategoryMap.set(item.category, true);
        finalSelected.push(item);
      }
    }

    // Second pass: fill up to 5 if needed
    for (const item of collectedItems) {
      if (finalSelected.length >= 5) break;
      if (!finalSelected.some(existing => existing.title === item.title)) {
        finalSelected.push(item);
      }
    }

    if (finalSelected.length === 0) {
      console.log('No articles found. Skipping Firestore sync.');
      return;
    }

    console.log(`Processing top ${finalSelected.length} cards...`);
    const processedItems = [];

    for (let i = 0; i < finalSelected.length; i++) {
      const item = finalSelected[i];
      let secureUrl = 'assets/images/carousel/jerusalem.jpg';

      if (item.rawImage) {
        try {
          console.log(`[${i + 1}/${finalSelected.length}] Uploading image: ${item.title.slice(0, 30)}...`);
          const uploadRes = await cloudinary.uploader.upload(item.rawImage, {
            folder: 'whats_new_news',
            transformation: [{ width: 800, height: 450, crop: 'fill', quality: 'auto', fetch_format: 'auto' }],
          });
          secureUrl = uploadRes.secure_url;
        } catch (uploadErr) {
          console.warn(`Cloudinary upload fallback for item ${i + 1}: ${uploadErr.message}`);
        }
      }

      processedItems.push({
        order: i + 1,
        title: item.title,
        category: item.category,
        pubDate: item.pubDate,
        imageUrl: secureUrl,
        link: item.link,
        snippet: item.snippet,
        fullContent: item.fullContent,
        sourceName: item.sourceName,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    const collectionRef = db.collection('whats_new');
    const existing = await collectionRef.get();
    const batch = db.batch();

    existing.docs.forEach((doc) => batch.delete(doc.ref));
    processedItems.forEach((docData) => {
      const newRef = collectionRef.doc();
      batch.set(newRef, docData);
    });

    await batch.commit();
    console.log(`Successfully published ${processedItems.length} diverse items to Firestore.`);
    process.exit(0);
  } catch (error) {
    console.error('Execution error:', error);
    process.exit(1);
  }
}

run();
