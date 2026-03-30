# Strategic Research: Steam & Google Play Integration

This document outlines the architectural requirements for publishing **Constellation** on Steam and Google Play, ensuring the backend is ready for a real "playable" experience.

## 1. Authentication Strategy

To support Steam and Google Play, the `auth` crate must evolve from simple username/password to **Identity Provider (IdP) integration**.

### Steam (Steamworks API)
- **Token Verification**: User provides a Steam Auth Ticket/Token from the client. The backend verifies this ticket via the `ISteamUser/AuthenticateUserTicket` Web API.
- **Steam ID**: Once verified, the `steam_id` becomes the primary key or is linked to the internal `user_id`.

### Google Play (Play Game Services)
- **OAuth2/OpenID Connect**: The client (Android) sends an ID Token. The backend verifies it using Google's public keys.
- **Player ID**: The `player_id` from Google Play is linked to the internal account.

## 2. Platform Services Logic

### Steamworks Features
- **Microtransactions**: Integration with Steam Microtransactions (Web API) for the "Market Engine".
- **Leaderboards & Achievements**: Backend-authoritative updates to avoid cheating.
- **Cloud Saves**: Syncing `player-state` with Steam Cloud.

### Google Play Services
- **Cloud Save**: Using Play Games Cloud Save.
- **In-App Billing**: Verification of Google Play Purchase Tokens on the backend.

## 3. Implementation Recommendations

1.  **Multi-Auth Handler**: Refactor `auth/src/handlers/login.rs` to support `LoginType` (Guest, Steam, Google).
2.  **SDK Selection**: Use `steamworks-rs` or simple HTTP clients for Web API calls.
3.  **Cross-Platform ID**: Implement a "Linking" system so a user can play on Steam and continue on Mobile (Google Play).

## 4. Market Engine Integration

For a real game, the **Nakama** engine is highly recommended as it has out-of-the-box support for:
- Steam/Google Auth
- Friends lists & Chat
- Economy & Virtual Wallets
- Matchmaking (for the combat engine)

> [!TIP]
> Since you mentioned evaluating a market engine, **Nakama** would solve 80% of these publishing requirements immediately.
