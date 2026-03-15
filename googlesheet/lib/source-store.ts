import fs from 'fs/promises';
import path from 'path';

export interface Post {
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

const STORE_PATH = path.join(process.cwd(), 'data', 'blog-store.json');
const DEFAULT_STORE: Store = { lastSyncedTime: '', posts: [] };

async function ensureStoreExists(): Promise<void> {
  const dir = path.dirname(STORE_PATH);
  try {
    await fs.access(dir);
  } catch {
    await fs.mkdir(dir, { recursive: true });
  }

  try {
    await fs.access(STORE_PATH);
  } catch {
    await fs.writeFile(STORE_PATH, JSON.stringify(DEFAULT_STORE, null, 2));
  }
}

export async function readStore(): Promise<Store> {
  await ensureStoreExists();
  const content = await fs.readFile(STORE_PATH, 'utf-8');
  return JSON.parse(content);
}

export async function writeStore(store: Store): Promise<void> {
  await ensureStoreExists();
  await fs.writeFile(STORE_PATH, JSON.stringify(store, null, 2));
}

export async function getLastSyncedTime(): Promise<string> {
  const store = await readStore();
  return store.lastSyncedTime;
}

export async function setLastSyncedTime(time: string): Promise<void> {
  const store = await readStore();
  store.lastSyncedTime = time;
  await writeStore(store);
}

export async function getAllPosts(): Promise<Post[]> {
  const store = await readStore();
  return store.posts.sort((a, b) => {
    if (a.pin && !b.pin) return -1;
    if (!a.pin && b.pin) return 1;
    if (a.pin && b.pin) return a.pin - b.pin;
    return new Date(b.create_time).getTime() - new Date(a.create_time).getTime();
  });
}

export async function getPostBySlug(slug: string): Promise<Post | null> {
  const store = await readStore();
  return store.posts.find(p => p.slug === slug) || null;
}

export async function writePosts(posts: Post[]): Promise<void> {
  const store = await readStore();
  const existingSlugs = new Set(store.posts.map(p => p.slug));
  
  for (const post of posts) {
    if (existingSlugs.has(post.slug)) {
      const index = store.posts.findIndex(p => p.slug === post.slug);
      store.posts[index] = post;
    } else {
      store.posts.push(post);
    }
  }
  
  await writeStore(store);
}

export async function writePost(post: Post): Promise<void> {
  await writePosts([post]);
}