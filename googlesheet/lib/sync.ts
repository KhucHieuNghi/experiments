import { revalidatePath } from 'next/cache';
import { fetchNewFromSheets, sourceStore } from './sheets-cache';

export async function syncNewPosts(): Promise<{ synced: number; message: string }> {
  try {
    const lastSyncedTime = await sourceStore.getLastSyncedTime();
    
    const newPosts = await fetchNewFromSheets(lastSyncedTime);
    
    if (newPosts.length === 0) {
      return { synced: 0, message: 'No new posts to sync' };
    }
    
    await sourceStore.writePosts(newPosts);
    
    const latestTime = newPosts[newPosts.length - 1].create_time;
    await sourceStore.setLastSyncedTime(latestTime);
    
    revalidatePath('/', 'layout');
    
    return { 
      synced: newPosts.length, 
      message: `Synced ${newPosts.length} post(s)` 
    };
  } catch (error) {
    console.error('Sync error:', error);
    throw error;
  }
}

export async function fullSync(): Promise<{ synced: number; message: string }> {
  try {
    const { fetchAllFromSheets } = await import('./sheets-cache');
    const allPosts = await fetchAllFromSheets();
    
    await sourceStore.writePosts(allPosts);
    
    if (allPosts.length > 0) {
      const sortedPosts = [...allPosts].sort((a, b) => 
        new Date(b.create_time).getTime() - new Date(a.create_time).getTime()
      );
      await sourceStore.setLastSyncedTime(sortedPosts[0].create_time);
    }
    
    revalidatePath('/', 'layout');
    
    return { 
      synced: allPosts.length, 
      message: `Full sync completed: ${allPosts.length} post(s)` 
    };
  } catch (error) {
    console.error('Full sync error:', error);
    throw error;
  }
}