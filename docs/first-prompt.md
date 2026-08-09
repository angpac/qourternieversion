Paste this as your first message to Claude Code, from inside the project folder, after `/init` has run and CLAUDE.md is in place.

---

I'm building Qourt, a badminton court rotation and tournament app. Context is in this repo:

- Product spec: `docs/Qourt_PRD.md`
- Design brief (visual direction, tech stack, full screen list): `docs/Qourt_Design_Brief.md`
- System architecture (backend structure, data flow, push notification paths): `docs/System_Architecture.md`
- Database schema for Supabase: `db/qourt_schema.sql`
- Figma screens file (32 designed frames, 6 sections): figma.com/design/Rq7kYFWULakImoFhoVbHSR
- Figma flow + architecture diagrams: figma.com/board/Kve9wPtbWQkrpTlaV8DdqD

CLAUDE.md has the tech stack and rules, read it first.

Start here, one step at a time, checking in after each:

1. Read the PRD, design brief, and system architecture doc fully.
2. Set up the Xcode project: SwiftUI iOS app target (iOS 17+) plus a watchOS companion target, both in one project.
3. Set up the Supabase project structure locally, run the schema in `db/qourt_schema.sql` against a fresh Supabase project, and wire up the Swift package for the Supabase client.
4. Build the Sign In With Apple flow end to end: Sign in screen, Choose Admin or Play screen, landing on My games (empty state is fine for now).
5. Stop there and show me what you've got before continuing to the rest of the screens.

Don't try to build all 32 screens in one pass. Get the first flow working end to end first.
