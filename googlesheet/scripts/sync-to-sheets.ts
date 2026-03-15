import { google } from 'googleapis';
import * as fs from 'fs';
import * as path from 'path';

const SPREADSHEET_ID = process.env.SPREADSHEET_ID || '1J7mxiMqTZZKOZ2vrcHoqVFY3FpzN3-9FoXFL77QmStU';
const STORE_PATH = path.join(process.cwd(), 'data', 'blog-store.json');

interface Post {
  slug: string;
  category: string;
  title: string;
  description: string;
  create_time: string;
  image?: string;
  pin?: number;
}

interface Store {
  lastSyncedTime: string;
  posts: Post[];
}

async function getAuth() {
  const credentialsPath = path.join(process.cwd(), 'credentials.json');
  
  if (!fs.existsSync(credentialsPath)) {
    throw new Error(
      'credentials.json not found!\n\n' +
      'Setup steps:\n' +
      '1. Go to https://console.cloud.google.com\n' +
      '2. Create Service Account with Editor role\n' +
      '3. Download JSON key and save as credentials.json\n' +
      '4. Share your Google Sheet with the service account email'
    );
  }

  const credentials = JSON.parse(fs.readFileSync(credentialsPath, 'utf-8'));
  
  return new google.auth.GoogleAuth({
    credentials,
    scopes: ['https://www.googleapis.com/auth/spreadsheets'],
  });
}

async function clearSheet(sheets: any, spreadsheetId: string) {
  await sheets.spreadsheets.values.clear({
    spreadsheetId,
    range: 'Sheet1!A:G',
  });
}

async function writePosts(sheets: any, spreadsheetId: string, posts: Post[]) {
  const headers = ['slug', 'category', 'title', 'description', 'create_time', 'image', 'pin'];
  
  const rows = [
    headers,
    ...posts.map(post => [
      post.slug,
      post.category,
      post.title,
      post.description,
      post.create_time,
      post.image || '',
      post.pin?.toString() || '',
    ]),
  ];

  await sheets.spreadsheets.values.update({
    spreadsheetId,
    range: 'Sheet1!A1',
    valueInputOption: 'RAW',
    requestBody: {
      values: rows,
    },
  });

  return rows.length - 1;
}

async function main() {
  console.log('📝 Syncing blog-store.json to Google Sheets...\n');

  if (!fs.existsSync(STORE_PATH)) {
    throw new Error('data/blog-store.json not found!');
  }

  const store: Store = JSON.parse(fs.readFileSync(STORE_PATH, 'utf-8'));
  const posts = store.posts;

  console.log(`Found ${posts.length} posts in blog-store.json`);

  const auth = await getAuth();
  const sheets = google.sheets({ version: 'v4', auth });

  console.log('Clearing existing data...');
  await clearSheet(sheets, SPREADSHEET_ID);

  console.log('Writing new data...');
  const count = await writePosts(sheets, SPREADSHEET_ID, posts);

  console.log(`\n✅ Successfully synced ${count} posts to Google Sheets!`);
  console.log(`📄 View: https://docs.google.com/spreadsheets/d/${SPREADSHEET_ID}`);
}

main().catch(err => {
  console.error('❌ Error:', err.message);
  process.exit(1);
});