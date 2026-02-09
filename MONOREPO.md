# Signal Mega Repository

This repository now contains:

- iOS app code at `Signal/`, `SignalShare/`, and `Signal.xcodeproj/`
- Backend code at `signal-backend/`

## Deployment Safety (Vercel)

The original backend repository at:

`/Users/oliver_stevenson/Documents/Servers/Signal-Backend`

is unchanged.

Vercel deployment for `signal-backend` is therefore unaffected unless you explicitly reconfigure Vercel to deploy from this mega repository.

## Local Development

- iOS app: open `Signal.xcodeproj`
- Backend: `cd signal-backend && npm install && npm run start`
