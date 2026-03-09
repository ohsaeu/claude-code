# Tech Stack

- Next.js 14
- TypeScript 5.2
- Tailwind CSS 3.4
- Prisma ORM
- PostgreSQL 15

# Structure

- `scc/app`: Next.js App Router pages
- `src/compoenets`: Reusable React components
- `src/lib`: Utility functions
- `src/types`: Typescript definitions

# Commands

- `npm run dev`: Start development server
- `npm run build`: Production build
- `npm run test`: Run Jest tests
- `npm run db:migrate`: Apply database migrations

# Code Style

- Components: PascalCase
- Files: kebab-case
- Functions: camelCase
- Constants: UPPER_SNAKE_CASE
- Imports: Group external -> internal -> relative

# Git Workflow

- Branches: feature/description, fix/description
- Commits: "type: description" (feat, fix, docs, style)
- Merge: Squash commits on main
