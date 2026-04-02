# Skill: Prisma Schema & API Scaffolding

## Purpose

This skill equips Copilot to add new Prisma models, generate migrations, and scaffold the corresponding Express controller + route files — all following the conventions already established in this Social Media API project.

Invoke this skill whenever asked to:
- Add a new feature backed by a database table (e.g., "add likes", "add followers")
- Extend an existing Prisma model with new fields
- Create a migration for schema changes
- Generate a new Express controller/route pair from a Prisma model
- Review or fix a Prisma schema
- Debug Prisma migration errors

---

## Project Context

| Detail | Value |
|---|---|
| ORM | Prisma 7 |
| Database | PostgreSQL (via `@prisma/adapter-pg`) |
| Schema file | `prisma/schema.prisma` |
| Migrations dir | `prisma/migrations/` |
| Generated client | `generated/prisma/` |
| Prisma config | `prisma.config.ts` |
| Singleton client | `lib/prisma.js` |
| Validation | Zod (`zod` package) |
| Auth middleware | `middleware/auth.js` — sets `req.user.userId` |

---

## Prisma Schema Conventions

Every model **must** follow these conventions without exception:

### 1. Primary Key
```prisma
id  String  @id @default(uuid()) @db.Uuid
```

### 2. Timestamps
Always add `createdAt`. Add `updatedAt` only when the resource is user-editable (e.g., profile, post content).
```prisma
createdAt  DateTime  @default(now())
updatedAt  DateTime  @updatedAt   // only when content is editable
```

### 3. Foreign Keys
Foreign key scalar fields must be typed `String @db.Uuid` to match the UUID primary keys.
```prisma
userId  String  @db.Uuid
user    User    @relation(fields: [userId], references: [id], onDelete: Cascade)
```

### 4. Cascade Deletes
Always use `onDelete: Cascade` on relations where child rows should be removed when the parent is deleted. This avoids orphaned records.

### 5. Self-Referential Relations (e.g., threaded comments)
```prisma
parentId  String?   @db.Uuid
parent    Model?    @relation("ModelToModel", fields: [parentId], references: [id], onDelete: Cascade)
children  Model[]   @relation("ModelToModel")
```

### Full Model Template
```prisma
model NewModel {
  id        String   @id @default(uuid()) @db.Uuid
  // ... your fields ...
  userId    String   @db.Uuid
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

---

## Migration Workflow

### Step 1 — Edit the Schema
Modify `prisma/schema.prisma` following the conventions above. Also add the back-relation on any referenced model (e.g., `newModels NewModel[]` on `User`).

### Step 2 — Create and Apply the Migration
```bash
npx prisma migrate dev --name <descriptive_name>
# Example: npx prisma migrate dev --name add_likes_to_posts
```
This automatically:
1. Generates SQL in `prisma/migrations/<timestamp>_<name>/migration.sql`
2. Applies it to the database
3. Regenerates the Prisma client

### Step 3 — Regenerate the Client (if schema-only change, no migration needed)
```bash
npm run prisma:generate
# equivalent to: npx prisma generate
```

### Common Migration Error Fixes
| Error | Fix |
|---|---|
| `P3006` — migration failed | Check `migration.sql`, fix SQL, then run `npx prisma migrate resolve --applied <migration_name>` |
| `P1001` — database unreachable | Verify `DATABASE_URL` in `.env` |
| `P3009` — failed migration in history | Run `npx prisma migrate resolve --rolled-back <migration_name>` then fix and re-run |
| Drift detected | Run `npx prisma migrate dev` — Prisma will prompt to reset if needed |

---

## Controller Conventions

Every controller file lives in `controller/` and must follow this pattern:

### Imports
```js
const { z } = require('zod');
const prisma = require('../lib/prisma');
```

### Zod Schema (one per endpoint that accepts a body)
```js
const createThingSchema = z.object({
  fieldName: z.string().min(1, 'fieldName is required'),
  // numeric example:
  count: z.number().int().positive('count must be positive'),
});
```

### Controller Function Template
```js
const createThing = async (req, res) => {
  try {
    const validation = createThingSchema.safeParse(req.body);
    if (!validation.success) {
      return res.status(422).json({
        error: 'Validation failed',
        details: validation.error.errors.map((e) => ({
          field: e.path.join('.'),
          message: e.message,
        })),
      });
    }

    const { fieldName } = validation.data;
    const thing = await prisma.thing.create({
      data: { fieldName, userId: req.user.userId },
      select: { id: true, fieldName: true, createdAt: true },
    });

    return res.status(201).json({ message: 'Thing created successfully', thing });
  } catch (error) {
    console.error('Error creating thing:', error);
    return res.status(500).json({ error: 'An error occurred while creating the thing' });
  }
};
```

### Authorization Guard (for owner-only mutations)
```js
if (resource.userId !== req.user.userId) {
  return res.status(403).json({ error: 'You are not authorized to perform this action.' });
}
```

### Prisma Error Codes to Handle
| Code | Meaning | HTTP Status |
|---|---|---|
| `P2002` | Unique constraint violation | 409 |
| `P2025` | Record not found (in update/delete) | 404 |

### Module Exports
```js
module.exports = { createThing, deleteThing, getThings };
```

---

## Route Conventions

Route files live in `routes/` and follow this pattern:

```js
const express = require('express');
const { createThing, deleteThing, getThings } = require('../controller/thing');
const { authenticate } = require('../middleware/auth');
const router = express.Router();

// Public routes (no auth)
router.get('/', getThings);

// Protected routes (require JWT)
router.post('/', authenticate, createThing);
router.delete('/:thingId', authenticate, deleteThing);

module.exports = router;
```

### Wiring the Router in `app.js`
Add the new router **before** the 404 handler:
```js
var thingRouter = require('./routes/thing');
// ...
app.use('/things', thingRouter);
```

---

## Step-by-Step: Adding a Complete New Feature

When asked to add a new feature (e.g., "add likes to posts"), follow these steps in order:

1. **Schema** — add the new model to `prisma/schema.prisma` using the conventions above
2. **Back-relations** — add the relation array to referenced models (`User`, `Post`, etc.)
3. **Migrate** — run `npx prisma migrate dev --name <descriptive_name>`
4. **Controller** — create `controller/<feature>.js` with Zod validation + Prisma calls
5. **Route** — create `routes/<feature>.js` wiring HTTP verbs to controller functions
6. **Wire** — require and mount the router in `app.js`

---

## Supporting Scripts

| Script | Purpose |
|---|---|
| `.github/skills/prisma-migration/scripts/scaffold-model.sh <ModelName>` | Generates a stub controller and route file for a new Prisma model |
| `.github/skills/prisma-migration/scripts/validate-schema.sh` | Validates the Prisma schema and checks for pending migrations |
