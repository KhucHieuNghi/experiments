import { NextRequest, NextResponse } from "next/server";
import { syncNewPosts, fullSync } from "@/lib/sync";

const SYNC_SECRET = process.env.SYNC_SECRET || "";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { secret, full } = body;

    if (SYNC_SECRET && secret !== SYNC_SECRET) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const result = full ? await fullSync() : await syncNewPosts();

    return NextResponse.json(result);
  } catch (error) {
    console.error("Sync API error:", error);
    return NextResponse.json(
      {
        error: "Sync failed",
        message: error instanceof Error ? error.message : "Unknown error",
      },
      { status: 500 },
    );
  }
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const secret = searchParams.get("secret");
  const full = searchParams.get("full") === "true";

  // if (SYNC_SECRET && secret !== SYNC_SECRET) {
  //   return NextResponse.json(
  //     { error: 'Unauthorized' },
  //     { status: 401 }
  //   );
  // }

  try {
    const result = full ? await fullSync() : await syncNewPosts();
    return NextResponse.json(result);
  } catch (error) {
    console.error("Sync API error:", error);
    return NextResponse.json(
      {
        error: "Sync failed",
        message: error instanceof Error ? error.message : "Unknown error",
      },
      { status: 500 },
    );
  }
}
