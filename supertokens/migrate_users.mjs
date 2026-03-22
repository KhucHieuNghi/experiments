import fs from 'node:fs/promises';
import path from 'node:path';

const BASE_URL = "https://";
const API_KEY = process.env.API_KEY || "{{api_key}}";
const SOURCE_FILE = './ticket_users.json';
const BATCH_SIZE = 500;

// Options for testing
const DRY_RUN = process.env.DRY_RUN === 'true';
const LIMIT = process.env.LIMIT ? parseInt(process.env.LIMIT, 10) : Infinity;

async function migrateUsers() {
  try {
    console.log(`Reading source data from ${SOURCE_FILE}...`);
    const data = await fs.readFile(SOURCE_FILE, 'utf-8');
    let users = JSON.parse(data);

    if (LIMIT < users.length) {
      console.log(`Limiting migration to the first ${LIMIT} users.`);
      users = users.slice(0, LIMIT);
    }

    console.log(`Total users to migrate: ${users.length}`);

    const batches = [];
    for (let i = 0; i < users.length; i += BATCH_SIZE) {
      batches.push(users.slice(i, i + BATCH_SIZE));
    }

    console.log(`Split into ${batches.length} batches of max ${BATCH_SIZE} records.`);

    if (DRY_RUN) {
      console.log('--- DRY RUN MODE ENABLED: No requests will be sent ---');
    }

    for (let i = 0; i < batches.length; i++) {
      const batch = batches[i];
      console.log(`Processing batch ${i + 1}/${batches.length} (${batch.length} users)...`);

      const transformedUsers = batch.map(user => ({
        externalUserId: user.id.toString(),
        userMetadata: [
          {
            name: user.name,
            username: user.username,
            phone: user.phone,
            gender: user.gender,
            address: user.address,
            birthday: user.birthday,
            legacy_status: user.status
          }
        ],
        // userRoles: [], // Optional: add if needed
        loginMethods: [
          {
            recipeId: "emailpassword",
            email: user.email,
            passwordHash: user.password,
            hashingAlgorithm: "bcrypt",
            isVerified: user.status === 1 || !!user.email_verified_at,
            timeJoinedInMSSinceEpoch: user.created_at ? new Date(user.created_at).getTime() : Date.now()
          }
        ]
      }));

      await uploadBatch(transformedUsers, i + 1);
    }

    console.log('Migration completed successfully.');
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

async function uploadBatch(users, batchIndex) {
  const url = `${BASE_URL}/appid-public/bulk-import/users`;
  const options = {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'api-key': API_KEY
    },
    body: JSON.stringify({ users })
  };

  if (DRY_RUN) {
    console.log(`[DRY RUN] Would upload batch ${batchIndex} with ${users.length} users.`);
    return;
  }

  const response = await fetch(url, options);
  const result = await response.json();

  if (!response.ok) {
    throw new Error(`Batch ${batchIndex} failed: ${JSON.stringify(result)}`);
  }

  console.log(`Batch ${batchIndex} uploaded successfully. Response:`, JSON.stringify(result));
}

migrateUsers();
