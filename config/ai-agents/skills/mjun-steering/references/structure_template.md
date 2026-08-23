# Project Structure

## Organization Philosophy

[構成の方針: feature-first、layered、domain-drivenなど]

## Directory Patterns

### [パターン名]

**Location**: `/path/`
**Purpose**: [ここに何を置くか]
**Example**: [簡潔な例]

### [パターン名]

**Location**: `/path/`
**Purpose**: [ここに何を置くか]
**Example**: [簡潔な例]

## Naming Conventions

- **Files**: [パターン。例: PascalCase、kebab-case]
- **Components**: [パターン]
- **Functions**: [パターン]

## Import Organization

```typescript
import { Something } from "@/path"; // 絶対パス
import { Local } from "./local"; // 相対パス
```

**Path Aliases**:

- `@/`: [対応するパス]

## Code Organization Principles

[主要なアーキテクチャパターンと依存関係のルール]

---

_パターンを書く。ファイルツリーを書かない。パターンに従う新規ファイルのために更新が必要になってはいけない_
