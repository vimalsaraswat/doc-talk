import { NextResponse } from "next/server";
import { type IVerifyResponse } from "@worldcoin/idkit";
import { verifyCloudProof } from "@worldcoin/idkit-core/backend";

const app_id = process.env.NEXT_PUBLIC_WLD_APP_ID as `app_${string}`;
const action = process.env.NEXT_PUBLIC_WLD_ACTION as string;

export async function POST(request: Request) {
  const proof = await request.json();

  const verifyRes = (await verifyCloudProof(proof, app_id, action)) as IVerifyResponse;

  if (verifyRes.success) {
    return NextResponse.json({ ...verifyRes }, { status: 200 });
  } else {
    return NextResponse.json({ ...verifyRes }, { status: 400 });
  }
}
