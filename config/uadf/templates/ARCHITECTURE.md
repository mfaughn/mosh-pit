# Architecture

High-level system design and component relationships.

---

## 1. System Overview

[Diagram or description of the overall system architecture]

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Client    │────▶│   Server    │────▶│  Database   │
└─────────────┘     └─────────────┘     └─────────────┘
```

---

## 2. Component Structure

### Frontend
```
src/
├── components/     # Reusable UI components
├── pages/          # Route-level components
├── hooks/          # Custom React hooks
├── utils/          # Utility functions
├── types/          # TypeScript types
└── services/       # API clients
```

### Backend (if applicable)
```
api/
├── routes/         # API route handlers
├── services/       # Business logic
├── models/         # Data models
└── middleware/     # Request middleware
```

---

## 3. Data Models

### [Model Name]
```typescript
interface User {
  id: string;
  email: string;
  createdAt: Date;
}
```

---

## 4. API Endpoints (if applicable)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/users` | List users |
| POST | `/api/users` | Create user |

---

## 5. External Integrations

| Service | Purpose | Documentation |
|---------|---------|---------------|
| [Service] | [What it's used for] | [Link] |

---

## 6. Conventions

### Naming
- Components: PascalCase (`UserProfile.tsx`)
- Utilities: camelCase (`formatDate.ts`)
- Constants: SCREAMING_SNAKE_CASE

### File Organization
- One component per file
- Co-locate tests with source (`Component.test.tsx`)
- Co-locate styles with components

### State Management
[Describe approach: React Context, Redux, Zustand, etc.]

---

## 7. Security Considerations

- [Authentication approach]
- [Authorization model]
- [Data validation strategy]
