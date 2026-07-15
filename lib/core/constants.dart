// ============================================================
// Core Constants — API base URL, routes, theme IDs
// ============================================================

class AppConstants {
  // ─── API ────────────────────────────────────────────────
  static const String baseUrl = 'https://testapi.spycenow.com';
  static const String apiV1 = '/api/v1';

  // ─── Auth Endpoints ─────────────────────────────────────
  static const String authRegister = '$apiV1/auth/register/';
  static const String authOtpVerify = '$apiV1/auth/otp/verify/';
  static const String authOtpResend = '$apiV1/auth/otp/resend/';
  static const String authLogout = '$apiV1/auth/logout/';
  static const String authWsTicket = '$apiV1/auth/ws-ticket/';
  static const String authSession = '$apiV1/auth/session/';
  static const String tokenRefresh = '$apiV1/token/refresh/';

  // ─── Profile Endpoints ──────────────────────────────────
  static const String profileMe = '$apiV1/profile/me/';
  static const String profileList = '$apiV1/profile/';
  static const String usersMe = '$apiV1/users/me/';
  static const String usersLastActive = '$apiV1/users/last-active/';

  // ─── Analytics & Telemetry ──────────────────────────────
  static const String analyticsEvents = '$apiV1/analytics/events/';
  static const String appVersion = '1.0.0';
  static const String profileUsernameAvailable = '$apiV1/profile/username-available/';

  // ─── Feed & Interaction ─────────────────────────────────
  static const String feed = '$apiV1/feed/';
  static const String interactionSend = '$apiV1/interaction/send/';
  static const String interactionPass = '$apiV1/interaction/pass/';
  static const String interactionAccept = '$apiV1/interaction/accept_request/';
  static const String interactionStartConversation = '$apiV1/interaction/start_conversation/';
  static const String interactionReceived = '$apiV1/interaction/received/';

  // ─── Matches ────────────────────────────────────────────
  static const String matches = '$apiV1/matches/';

  // ─── Chat ───────────────────────────────────────────────
  static const String conversations = '$apiV1/conversations/';
  static const String messages = '$apiV1/messages/';

  // ─── WebSocket (real-time chat & calls) ─────────────────
  static const String wsBase = 'wss://testapi.spycenow.com/ws';
  /// Origin sent on native WebSocket handshakes (must match backend CORS).
  static const String wsOrigin = 'https://testfrontend.spycenow.com';

  // ─── Calls (WebRTC signaling + ICE) ─────────────────────
  static const String callIceServers = '$apiV1/call/ice-servers/';
  static const String callQuota = '$apiV1/call/quota/';
  static const String callMetrics = '$apiV1/call/metrics/';
  static const String callIceState = '$apiV1/call/ice-state/';
  static const String callNetworkProfile = '$apiV1/call/network-profile/';

  // ─── Social (Confessions) ───────────────────────────────
  static const String social = '$apiV1/social/';
  static const String socialFeed = '$apiV1/social/feed/';
  static const String socialMoods = '$apiV1/social/moods/';
  static const String confessionRequests = '$apiV1/confession-requests/';

  // ─── Images ─────────────────────────────────────────────
  static const String imagesUpload = '$apiV1/images/upload/';
  static const String imagesReorder = '$apiV1/images/reorder/';

  // ─── Theme ──────────────────────────────────────────────
  static const String themeMe = '$apiV1/theme/me/';
  static const String themeOptions = '$apiV1/theme/options/';

  // ─── Options (Lookup lists) ──────────────────────────────
  static const String genders = '$apiV1/genders/';
  static const String sexualities = '$apiV1/sexualities/';
  static const String intents = '$apiV1/intents/';
  static const String languages = '$apiV1/languages/';
  static const String turnOns = '$apiV1/turn_ons/';
  static const String moodOptions = '$apiV1/mood_options/';
  static const String avatars = '$apiV1/avatars/';

  // ─── Verification ───────────────────────────────────────
  static const String verificationStatus = '$apiV1/verification/status/';
  static const String verificationUpload = '$apiV1/verification/upload/';
  static const String verificationChallenge = '$apiV1/verification/challenge/';
  static const String verificationFaceioComplete =
      '$apiV1/verification/faceio-complete/';
  static const String verificationMockComplete =
      '$apiV1/verification/mock-complete/';

  // ─── Subscription ───────────────────────────────────────
  static const String subscriptionMe = '$apiV1/subscription/me/';
  static const String subscriptionPurchase = '$apiV1/subscription/purchase/';

  // ─── Moderation ─────────────────────────────────────────
  static const String moderationBlock = '$apiV1/moderation/moderation/block/';
  static const String moderationReport = '$apiV1/moderation/moderation/report/';
  static const String moderationReportAndBlock = '$apiV1/moderation/moderation/report_and_block/';

  // ─── Paper Plane ─────────────────────────────────────────────
  static const String paperPlaneBase = '$apiV1/paper-plane/';
  static const String paperPlaneLaunch = '$apiV1/paper-plane/launch/';
  static const String paperPlaneMyPlanes = '$apiV1/paper-plane/my-planes/';
  static const String paperPlaneSky = '$apiV1/paper-plane/sky/';
  static const String paperPlaneCatchSkyPlane = '$apiV1/paper-plane/catch-sky-plane/';
  static const String paperPlaneInbox = '$apiV1/paper-plane/inbox/';

  // ─── Storage Keys ───────────────────────────────────────
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserEmail = 'user_email';
  static const String keyDeviceId = 'device_id';
  static const String keyIsNewUser = 'is_new_user';
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyLikeTtlCache = 'like_ttl_cache';

  /// Matches backend Redis LIKE_TTL (36 hours).
  static const int likeTtlSeconds = 129600;

  // ─── Theme ID Registry ──────────────────────────────────
  // Layouts: stable IDs the backend assigns. Flutter owns visuals.
  static const Map<String, String> layoutNames = {
    'L01': 'Classic',
    'L02': 'Split',
    'L03': 'Immersive',
    'L04': 'Minimal',
    'L05': 'Bold',
  };

  static const List<String> layoutIds = [
    'L01', 'L02', 'L03', 'L04', 'L05',
  ];

  // Backgrounds and their variants (bg_variant_id → color_token on backend)
  static const Map<String, String> backgroundNames = {
    'B01': 'Flame Wave',
    'B02': 'Puzzle Splash',
    'B03': 'Hexagon Splash',
    'B04': 'Bi Splash',
    'B05': 'Square Splash',
    'B06': 'Advance Flame',
    'B07': 'Octagon Splash',
  };

  static const Map<String, List<String>> backgroundVariants = {
    'B01': ['B01-sunset', 'B01-ocean', 'B01-midnight'],
    'B02': ['B02-pink', 'B02-teal', 'B02-violet'],
    'B03': ['B03-gold', 'B03-coral', 'B03-ice'],
    'B04': ['B04-emerald', 'B04-rose'],
    'B05': ['B05-slate', 'B05-amber'],
    'B06': ['B06-cyan', 'B06-magenta', 'B06-lime'],
    'B07': ['B07-peach', 'B07-lavender', 'B07-mint'],
  };

  // ─── Brand Colors ────────────────────────────────────────
  static const int brandPinkHex = 0xFFFF2E74;
  static const int bgDarkHex = 0xFF0C0C0C;
  static const int surfaceDarkHex = 0xFF141416;
  static const int cardDarkHex = 0xFF1E1E1E;
}
