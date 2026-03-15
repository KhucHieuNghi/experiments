import * as sourceStore from './source-store';

export interface Post {
  slug: string;
  category: string;
  title: string;
  description: string;
  create_time: string;
  image?: string;
  pin?: number;
}

const SPREADSHEET_ID = process.env.SPREADSHEET_ID || '1J7mxiMqTZZKOZ2vrcHoqVFY3FpzN3-9FoXFL77QmStU';
const GVIZ_BASE_URL = `https://docs.google.com/spreadsheets/d/${SPREADSHEET_ID}/gviz/tq?tqx=out:json`;

const TTL = 12 * 60 * 60 * 1000;
let cache: Post[] | null = null;
let cacheTime = 0;
let inflightRequest: Promise<Post[]> | null = null;

function parseGvizResponse(text: string): Post[] {
  const jsonMatch = text.match(/google\.visualization\.Query\.setResponse\(([\s\S]*)\);?$/);
  if (!jsonMatch) return [];
  
  const data = JSON.parse(jsonMatch[1]);
  const rows = data.table?.rows || [];
  
  return rows.map((row: { c: Array<{ v: string | null }> }) => {
    const cells = row.c || [];
    return {
      slug: cells[0]?.v || '',
      category: cells[1]?.v || '',
      title: cells[2]?.v || '',
      description: cells[3]?.v || '',
      create_time: cells[4]?.v || '',
      image: cells[5]?.v || undefined,
      pin: cells[6]?.v ? parseInt(cells[6].v as string) : undefined,
    };
  }).filter((post: Post) => post.slug && post.title);
}

export async function fetchFromSheets(query: string): Promise<Post[]> {
  const url = `${GVIZ_BASE_URL}&tq=${encodeURIComponent(query)}`;
  const response = await fetch(url, { next: { revalidate: 43200 } });
  const text = await response.text();
  return parseGvizResponse(text);
}

export async function fetchAllFromSheets(): Promise<Post[]> {
  return fetchFromSheets("SELECT * ORDER BY G ASC, E DESC");
}

export async function fetchNewFromSheets(sinceTime: string): Promise<Post[]> {
  if (!sinceTime) return fetchAllFromSheets();
  return fetchFromSheets(`SELECT * WHERE E > '${sinceTime}' ORDER BY E ASC`);
}

export async function fetchBySlugFromSheets(slug: string): Promise<Post | null> {
  const posts = await fetchFromSheets(`SELECT * WHERE A='${slug}' LIMIT 1`);
  return posts[0] || null;
}

export async function getPosts(): Promise<Post[]> {
  const now = Date.now();
  
  const sourcePosts = await sourceStore.getAllPosts();
  if (sourcePosts.length > 0) {
    return sourcePosts;
  }
  
  if (cache && now - cacheTime < TTL) {
    return cache;
  }
  
  if (inflightRequest) {
    return inflightRequest;
  }
  
  inflightRequest = fetchAllFromSheets()
    .then(data => {
      cache = data;
      cacheTime = Date.now();
      inflightRequest = null;
      return data;
    })
    .catch(err => {
      inflightRequest = null;
      if (cache) return cache;
      throw err;
    });
  
  return inflightRequest;
}

export async function getPostBySlug(slug: string): Promise<Post | null> {
  const fromSource = await sourceStore.getPostBySlug(slug);
  if (fromSource) return fromSource;
  
  const fromSheets = await fetchBySlugFromSheets(slug);
  if (!fromSheets) return null;
  
  await sourceStore.writePost(fromSheets);
  return fromSheets;
}

export { sourceStore };