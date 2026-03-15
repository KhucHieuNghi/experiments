import Link from 'next/link';
import { notFound } from 'next/navigation';
import { marked } from 'marked';
import { getPostBySlug, getPosts } from '@/lib/sheets-cache';

export async function generateStaticParams() {
  const posts = await getPosts();
  return posts.map((post) => ({
    slug: post.slug,
  }));
}

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

export default async function BlogPost({ 
  params 
}: { 
  params: Promise<{ slug: string }> 
}) {
  const { slug } = await params;
  const post = await getPostBySlug(slug);

  if (!post) {
    notFound();
  }

  const htmlContent = await marked(post.description);

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-4xl mx-auto px-4 py-12">
        <Link
          href="/"
          className="inline-flex items-center text-blue-600 hover:text-blue-800 mb-8"
        >
          ← Quay lại danh sách
        </Link>

        <article className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
          {post.image && (
            <img 
              src={post.image} 
              alt={post.title}
              className="w-full h-64 object-cover"
            />
          )}
          
          <div className="p-8">
            <div className="flex items-center gap-3 mb-4">
              <span className="inline-block px-3 py-1 text-sm font-medium bg-blue-100 text-blue-800 rounded-full">
                {post.category}
              </span>
              {post.create_time && (
                <time className="text-sm text-gray-500">
                  {formatDate(post.create_time)}
                </time>
              )}
            </div>
            
            <h1 className="text-3xl font-bold text-gray-900 mb-6">
              {post.title}
            </h1>
            
            <div 
              className="prose prose-lg prose-gray max-w-none prose-headings:text-gray-900 prose-a:text-blue-600"
              dangerouslySetInnerHTML={{ __html: htmlContent }}
            />
          </div>
        </article>
      </div>
    </div>
  );
}