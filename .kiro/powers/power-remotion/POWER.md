---
name: "remotion"
displayName: "Remotion"
description: "Create programmatic videos with React using Remotion. Search documentation, build compositions, animate properties, render videos via CLI/Lambda/Cloud Run."
keywords: ["remotion", "video", "programmatic video", "react video", "animation", "render video", "composition"]
author: "AIE-Skills"
---

# Remotion Power

Kết nối agent với Remotion documentation qua MCP — tra cứu API, patterns, best practices khi tạo video bằng React.

## Overview

Remotion là framework tạo video bằng React. Ý tưởng cốt lõi: video = function of images over time. Mỗi frame là một React component, thay đổi content mỗi frame tạo ra animation.

Core concepts:
- **Composition**: Đăng ký video với metadata (width, height, fps, durationInFrames)
- **Sequence**: Time-shift components, tạo timeline
- **useCurrentFrame()**: Hook trả về frame hiện tại — driver chính cho mọi animation
- **interpolate()**: Map frame range → value range (opacity, position, scale...)
- **spring()**: Physics-based animation (0→1 với overshoot)
- **`<Player>`**: Embed video trong React app
- **Render**: CLI, Node.js API, Lambda, Cloud Run

## Onboarding

### 1. Prerequisites

- Node.js ≥ 16 hoặc Bun ≥ 1.0.3
- npx available (đi kèm npm)

### 2. Scaffold Project

```bash
npx create-video@latest
```

Chọn template phù hợp (Hello World cho lần đầu).

### 3. Start Studio

```bash
# Regular templates
npx remotion studio

# Next.js / React Router 7 templates
npm run dev
```

### 4. MCP Server

Power này dùng official Remotion MCP server — index toàn bộ Remotion docs vào vector database:

```
npx @remotion/mcp@latest
```

Không cần API key, không cần config thêm.

> ⚠️ MCP server đang trong test phase — chưa có authentication. Remotion có thể restrict usage nếu chi phí cao.

### 5. Verify Connection

Hỏi agent:
- "How do I create a fade-in animation in Remotion?"
- "What are the props for `<Composition>`?"

## Available Tools

MCP server cung cấp tool tra cứu Remotion documentation:

- **remotion-documentation** — Search và retrieve Remotion docs, API references, examples, best practices

## Common Workflows

### Workflow 1: Tạo Video Mới

```
1. Scaffold project: npx create-video@latest
2. Tạo component trong src/ — dùng useCurrentFrame() + interpolate()
3. Register trong src/Root.tsx với <Composition>
4. Preview: npx remotion studio
5. Render: npx remotion render <composition-id>
```

### Workflow 2: Animation

```
// Fade in
const frame = useCurrentFrame();
const opacity = interpolate(frame, [0, 30], [0, 1], {
  extrapolateRight: "clamp",
});

// Spring bounce
const scale = spring({ fps, frame });

// Slide in
const translateX = interpolate(frame, [0, 30], [-100, 0], {
  extrapolateRight: "clamp",
});
```

### Workflow 3: Timeline với Sequences

```tsx
<>
  <Sequence durationInFrames={90}>
    <Intro />
  </Sequence>
  <Sequence from={90} durationInFrames={60}>
    <MainContent />
  </Sequence>
  <Sequence from={150}>
    <Outro />
  </Sequence>
</>
```

### Workflow 4: Transitions

```bash
npx remotion add @remotion/transitions
```

Dùng `<TransitionSeries>` với các effects: fade, slide, wipe, flip, clockWipe, iris, cube.

### Workflow 5: Render

```bash
# Render video (H.264 default)
npx remotion render MyComposition

# Render với codec cụ thể
npx remotion render MyComposition --codec=h265

# Render với props
npx remotion render MyComposition --props='{"name": "World"}'

# Render image sequence
npx remotion render MyComposition --sequence

# Render still image
npx remotion still MyComposition

# Scale output
npx remotion render MyComposition --scale=1.5
```

### Workflow 6: Embed Player trong React App

```tsx
import { Player } from "@remotion/player";
import { MyComposition } from "./MyComposition";

<Player
  component={MyComposition}
  durationInFrames={150}
  fps={30}
  compositionWidth={1920}
  compositionHeight={1080}
  inputProps={{ name: "World" }}
/>
```

### Workflow 7: Lambda Rendering

```bash
# Setup
npx remotion lambda policies role
npx remotion lambda sites create
npx remotion lambda functions deploy

# Render
npx remotion lambda render <site-url> <composition-id>
```

Yêu cầu: AWS account, IAM permissions, supported regions.

## Key API Packages

| Package | Purpose |
|---------|---------|
| `remotion` | Core: useCurrentFrame, interpolate, spring, Composition, Sequence |
| `@remotion/player` | Embed video trong React app |
| `@remotion/renderer` | Server-side rendering API |
| `@remotion/lambda` | Render trên AWS Lambda |
| `@remotion/cloudrun` | Render trên GCP Cloud Run |
| `@remotion/transitions` | TransitionSeries, fade, slide, wipe... |
| `@remotion/captions` | Subtitle operations |
| `@remotion/three` | 3D video với React Three Fiber |
| `@remotion/lottie` | Lottie animations |
| `@remotion/gif` | GIF trong video |
| `@remotion/media-utils` | Video/audio info |
| `@remotion/noise` | Noise effects |
| `@remotion/shapes` | SVG shapes |
| `@remotion/paths` | SVG path manipulation |
| `@remotion/google-fonts` | Google Fonts |
| `@remotion/tailwind` | TailwindCSS v3 |
| `@remotion/tailwind-v4` | TailwindCSS v4 |
| `@remotion/zod-types` | Zod schemas cho visual editing |
| `@remotion/install-whisper-cpp` | Whisper.cpp transcription |
| `@remotion/openai-whisper` | OpenAI Whisper transcriptions |
| `@remotion/elevenlabs` | ElevenLabs transcriptions |
| `@remotion/motion-blur` | Motion blur effects |
| `@remotion/light-leaks` | Light leak effects |
| `@remotion/sfx` | Sound effects |

## AI-Friendly Documentation Tips

Remotion docs được tối ưu cho AI agents:
- **Copy as Markdown**: Click copy button trên bất kỳ doc page
- **Markdown URLs**: Thêm `.md` vào URL (e.g., `remotion.dev/docs/player.md`)
- **Content negotiation**: Request `Accept: text/markdown` header để nhận markdown thay vì HTML

## Connected Skills

| Situation | Skill | Why |
|-----------|-------|-----|
| Frontend UI cho Player | frontend-dev-guidelines | React/TypeScript patterns |
| Deploy video app | deploy | Vercel, Netlify, AWS |
| 3D scenes | threejs | React Three Fiber integration |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| MCP server không connect | Kiểm tra `npx @remotion/mcp@latest` chạy được không, cần Node ≥ 16 |
| Flickering khi render | KHÔNG dùng CSS transitions/animations — chỉ dùng `useCurrentFrame()` |
| Video quá nặng | Giảm `--concurrency`, dùng `--jpeg-quality` thấp hơn, hoặc `--codec=h265` |
| Lambda timeout | Video > 80 phút Full HD sẽ timeout — dùng server-side rendering thay thế |
| Fonts không load | Dùng `@remotion/google-fonts` hoặc `@remotion/fonts` thay vì CSS @import |

## Anti-Patterns

| Agent nghĩ | Thực tế |
|-------------|---------|
| "Dùng CSS animation cho effects" | KHÔNG — chỉ dùng `useCurrentFrame()` + `interpolate()`. CSS animations gây flickering khi render |
| "Dùng setTimeout/setInterval" | KHÔNG — Remotion render từng frame độc lập, timing-based code sẽ break |
| "Video properties hardcode trong component" | Dùng `useVideoConfig()` để lấy fps, width, height, durationInFrames |
| "Render trực tiếp trong browser" | Browser chỉ preview — render final dùng CLI hoặc Node.js API |
| "Dùng `<video>` tag HTML thường" | Dùng `<OffthreadVideo>` hoặc `<Video>` từ remotion package |
