import Link from 'next/link';
import { getPosts } from '@/lib/sheets-cache';

function formatDate(dateStr: string): string {
  if (!dateStr) return '';
  try {
    const date = new Date(dateStr);
    return date.toLocaleDateString('vi-VN', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  } catch {
    return dateStr;
  }
}

function truncate(text: string, maxLength: number = 150): string {
  if (!text) return '';
  const stripped = text.replace(/[#*`_\[\]]/g, '');
  if (stripped.length <= maxLength) return stripped;
  return stripped.substring(0, maxLength).trim() + '...';
}

export default async function Home() {
  const posts = await getPosts();

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-4xl mx-auto px-4 py-12">
        <header className="mb-12">
          <h1 className="text-4xl font-bold text-gray-900 mb-2">Blog</h1>
          <p className="text-gray-600">Bài viết từ Google Sheets</p>
        </header>

        <main>
          {posts.length === 0 ? (
            <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-8 text-center">
              <p className="text-gray-500">Chưa có bài viết nào.</p>
              <p className="text-sm text-gray-400 mt-2">
                Chạy sync để lấy dữ liệu từ Google Sheets.
              </p>
            </div>
          ) : (
            <div className="grid gap-6">
              {posts.map((post) => (
                <article
                  key={post.slug}
                  className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition-shadow"
                >
                  <Link href={`/blog/${post.slug}`} className="flex">
                    {post.image && (
                      <div className="w-48 flex-shrink-0">
                        <img 
                          src={post.image} 
                          alt={post.title}
                          className="w-full h-full object-cover"
                        />
                      </div>
                    )}
                    <div className="flex-1 p-6">
                      <div className="flex items-center gap-3 mb-2">
                        {post.pin && (
                          <span className="inline-flex items-center gap-1 px-2 py-1 text-xs font-medium bg-amber-100 text-amber-800 rounded">
                            📌 Pinned
                          </span>
                        )}
                        <span className="inline-block px-2 py-1 text-xs font-medium bg-blue-100 text-blue-800 rounded">
                          {post.category}
                        </span>
                        {post.create_time && (
                          <time className="text-xs text-gray-400">
                            {formatDate(post.create_time)}
                          </time>
                        )}
                      </div>
                      <h2 className="text-xl font-semibold text-gray-900 mb-2 hover:text-blue-600">
                        {post.title}
                      </h2>
                      <p className="text-gray-600 text-sm line-clamp-2">
                        {truncate(post.description)}
                      </p>
                    </div>
                  </Link>
                </article>
              ))}
            </div>
          )}
        </main>
      </div>
    </div>
  );
}