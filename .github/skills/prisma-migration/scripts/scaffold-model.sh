#!/usr/bin/env bash
# scaffold-model.sh — Generates a stub controller and route file for a new Prisma model.
#
# Usage:
#   bash .github/skills/prisma-migration/scripts/scaffold-model.sh <ModelName>
#
# Example:
#   bash .github/skills/prisma-migration/scripts/scaffold-model.sh Like
#
# What it creates:
#   controller/<model_lower>.js   — Zod-validated create/delete/get stubs
#   routes/<model_lower>.js       — Express router wired to controller
#
# After running this script:
#   1. Add the Prisma model to prisma/schema.prisma
#   2. Run: npx prisma migrate dev --name add_<model_lower>
#   3. Fill in the Prisma select fields and business logic in the controller
#   4. Mount the new router in app.js

set -euo pipefail

# ── Argument validation ──────────────────────────────────────────────────────
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <ModelName>"
  echo "  ModelName must be PascalCase (e.g. Like, Follower, Reaction)"
  exit 1
fi

MODEL="$1"

# Validate PascalCase input (letters only, starts with uppercase)
if [[ ! "$MODEL" =~ ^[A-Z][a-zA-Z]+$ ]]; then
  echo "Error: ModelName must be PascalCase (e.g. Like, Follower, Reaction)"
  exit 1
fi

# ── Derive names ─────────────────────────────────────────────────────────────
MODEL_LOWER="${MODEL,}"                   # Like  -> like
MODEL_UPPER="${MODEL^^}"                  # Like  -> LIKE  (for log labels)
CONTROLLER_FILE="controller/${MODEL_LOWER}.js"
ROUTE_FILE="routes/${MODEL_LOWER}.js"

# ── Guard against overwriting existing files ──────────────────────────────────
for FILE in "$CONTROLLER_FILE" "$ROUTE_FILE"; do
  if [[ -f "$FILE" ]]; then
    echo "Error: $FILE already exists. Remove it first or choose a different model name."
    exit 1
  fi
done

# ── Generate controller ───────────────────────────────────────────────────────
cat > "$CONTROLLER_FILE" <<CONTROLLER
const { z } = require('zod');
const prisma = require('../lib/prisma');

// TODO: adjust fields to match your Prisma model
const create${MODEL}Schema = z.object({
  // Example: content: z.string().min(1, 'content is required'),
});

const create${MODEL} = async (req, res) => {
  try {
    const validation = create${MODEL}Schema.safeParse(req.body);
    if (!validation.success) {
      return res.status(422).json({
        error: 'Validation failed',
        details: validation.error.errors.map((e) => ({
          field: e.path.join('.'),
          message: e.message,
        })),
      });
    }

    // TODO: destructure validated fields from validation.data
    // const { fieldName } = validation.data;

    const ${MODEL_LOWER} = await prisma.${MODEL_LOWER}.create({
      data: {
        // TODO: add your fields here
        userId: req.user.userId,
      },
      // TODO: specify which fields to return
      select: { id: true, createdAt: true },
    });

    return res.status(201).json({
      message: '${MODEL} created successfully',
      ${MODEL_LOWER},
    });
  } catch (error) {
    if (error.code === 'P2002') {
      return res.status(409).json({ error: '${MODEL} already exists.' });
    }
    console.error('Error creating ${MODEL_LOWER}:', error);
    return res.status(500).json({ error: 'An error occurred while creating the ${MODEL_LOWER}' });
  }
};

const delete${MODEL} = async (req, res) => {
  try {
    const { ${MODEL_LOWER}Id } = req.params;

    const ${MODEL_LOWER} = await prisma.${MODEL_LOWER}.findUnique({
      where: { id: ${MODEL_LOWER}Id },
      select: { userId: true },
    });

    if (!${MODEL_LOWER}) {
      return res.status(404).json({ error: '${MODEL} not found.' });
    }

    if (${MODEL_LOWER}.userId !== req.user.userId) {
      return res.status(403).json({ error: 'You are not authorized to delete this ${MODEL_LOWER}.' });
    }

    await prisma.${MODEL_LOWER}.delete({ where: { id: ${MODEL_LOWER}Id } });

    return res.status(200).json({ message: '${MODEL} deleted successfully.' });
  } catch (error) {
    console.error('Error deleting ${MODEL_LOWER}:', error);
    return res.status(500).json({ error: 'An error occurred while deleting the ${MODEL_LOWER}' });
  }
};

const get${MODEL}s = async (req, res) => {
  try {
    // TODO: add filters (e.g. by postId, by userId) via req.params or req.query
    const ${MODEL_LOWER}s = await prisma.${MODEL_LOWER}.findMany({
      orderBy: { createdAt: 'desc' },
      // TODO: add select or include as needed
    });

    return res.status(200).json({
      message: '${MODEL}s retrieved successfully',
      ${MODEL_LOWER}s,
      totalCount: ${MODEL_LOWER}s.length,
    });
  } catch (error) {
    console.error('Error retrieving ${MODEL_LOWER}s:', error);
    return res.status(500).json({ error: 'An error occurred while retrieving ${MODEL_LOWER}s' });
  }
};

module.exports = { create${MODEL}, delete${MODEL}, get${MODEL}s };
CONTROLLER

# ── Generate route ────────────────────────────────────────────────────────────
cat > "$ROUTE_FILE" <<ROUTE
const express = require('express');
const { create${MODEL}, delete${MODEL}, get${MODEL}s } = require('../controller/${MODEL_LOWER}');
const { authenticate } = require('../middleware/auth');
const router = express.Router();

// Public
router.get('/', get${MODEL}s);

// Protected
router.post('/', authenticate, create${MODEL});
router.delete('/:${MODEL_LOWER}Id', authenticate, delete${MODEL});

module.exports = router;
ROUTE

# ── Success summary ───────────────────────────────────────────────────────────
echo ""
echo "Scaffolded files:"
echo "  $CONTROLLER_FILE"
echo "  $ROUTE_FILE"
echo ""
echo "Next steps:"
echo "  1. Add the ${MODEL} model to prisma/schema.prisma"
echo "  2. npx prisma migrate dev --name add_${MODEL_LOWER}"
echo "  3. Fill in field names and Prisma selects in $CONTROLLER_FILE"
echo "  4. Mount the router in app.js:"
echo "       var ${MODEL_LOWER}Router = require('./routes/${MODEL_LOWER}');"
echo "       app.use('/${MODEL_LOWER}s', ${MODEL_LOWER}Router);"
